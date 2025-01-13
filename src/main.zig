const command = @import("command.zig");
const options = @import("options.zig");
const pausable_timer = @import("pausable_timer.zig");
const signalfd = @import("signalfd.zig");
const std = @import("std");
const step = @import("step.zig");
const terminal = @import("terminal.zig");

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
    const stdout = std.io.getStdOut().writer();

    var poller = try command.Poller.init(allocator);
    defer poller.deinit();

    var current = step.Step{};
    while (true) : (current = current.next(settings.num_pomodoros)) {
        var timer = try pausable_timer.PausableTimer.init();

        const length = current.length(settings);
        var remaining = length;

        while (remaining > 0) : (remaining = length -| timer.read()) {
            try printStatus(
                allocator,
                stdout,
                current,
                settings.num_pomodoros,
                remaining,
                timer.paused,
            );

            if (try poller.pollTimeout(std.time.ns_per_s)) |command_| {
                switch (command_) {
                    command.Command.Quit => {
                        try stdout.print("\n", .{});
                        return;
                    },
                    command.Command.Pause => {
                        try timer.togglePause();
                    },
                    command.Command.Reset => {
                        current = step.Step{};
                        try timer.reset();
                    },
                }
            }
        }
    }
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
