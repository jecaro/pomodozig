const options = @import("options.zig");
const signalfd = @import("signalfd.zig");
const std = @import("std");
const step = @import("step.zig");
const terminal = @import("terminal.zig");
const time_extra = @import("time/extra.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    const program_and_args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, program_and_args);

    const program = program_and_args[0];
    const args = program_and_args[1..];

    const stdout = std.io.getStdOut().writer();

    const opts = options.parseArgs(args) catch {
        try printUsage(allocator, stdout, program);
        std.process.exit(1);
    };

    switch (opts) {
        .help => {
            try printUsage(allocator, stdout, program);
        },
        .settings => |settings| {
            try run(allocator, settings);
        },
    }
}

fn run(allocator: std.mem.Allocator, settings: options.Settings) !void {
    const term = try terminal.init(std.posix.STDIN_FILENO);
    defer terminal.deinit(term);

    const stdout = std.io.getStdOut().writer();

    const signalFile = try signalfd.open();
    defer signalFile.close();

    var poller = std.io.poll(
        allocator,
        enum { stdin, signalfd },
        .{
            .stdin = std.io.getStdIn(),
            .signalfd = signalFile,
        },
    );
    defer poller.deinit();

    var current = step.Step{};
    while (true) : (current = current.next(settings.num_pomodoros)) {
        var timer = try std.time.Timer.start();
        const length = current.length(settings);
        var paused = true;

        while (time_extra.read_paused(&timer, paused) < length) {
            const remaining = length - time_extra.read_paused(&timer, paused);
            try printStatus(
                allocator,
                stdout,
                current,
                settings.num_pomodoros,
                remaining,
                paused,
            );

            _ = try poller.pollTimeout(std.time.ns_per_s) or break;
            if (poller.fifo(.stdin).readItem()) |char| {
                switch (char) {
                    'q' => {
                        try stdout.print("\n", .{});
                        return;
                    },
                    'p' => {
                        paused = try togglePause(paused, &timer);
                    },
                    else => {},
                }
            }

            if (try signalfd.read(poller.fifo(.signalfd))) |siginfo| {
                switch (siginfo.signo) {
                    std.os.linux.SIG.USR1 => {
                        paused = try togglePause(paused, &timer);
                    },
                    else => unreachable,
                }
            }
        }
    }
}

fn togglePause(pause: bool, timer: *std.time.Timer) !bool {
    // when restarting we offset the started field of the time of the time that
    // has passed since the pause started
    if (pause) {
        //        running         paused
        //    |-------------|----------------|
        // started      previous             now
        const now = try std.time.Instant.now();
        const since_paused_nsec: u64 = now.since(timer.previous);
        timer.started = time_extra.add_ns(
            timer.started,
            since_paused_nsec,
        );
    }
    return !pause;
}

fn printStatus(
    allocator: std.mem.Allocator,
    out: std.fs.File.Writer,
    current: step.Step,
    num_pomodoros: u32,
    remaining: u64,
    paused: bool,
) !void {
    const msg = try current.render(allocator, num_pomodoros, remaining, paused);
    defer allocator.free(msg);

    try out.print("\x1b[2K\r{s}", .{msg});
}

fn printUsage(
    allocator: std.mem.Allocator,
    out: std.fs.File.Writer,
    program: []const u8,
) !void {
    const usage = try options.usage(allocator, program);
    defer allocator.free(usage);

    try out.print("{s}", .{usage});
}

test "main.zig" {
    std.testing.refAllDecls(@This());
}
