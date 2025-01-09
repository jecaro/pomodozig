const options = @import("options.zig");
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
    const term = try terminal.init(std.posix.STDIN_FILENO);
    defer terminal.deinit(term);

    const stdout = std.io.getStdOut().writer();

    var poller = std.io.poll(
        allocator,
        enum { stdin },
        .{ .stdin = std.io.getStdIn() },
    );
    defer poller.deinit();

    var current = step.Step{};
    while (true) : ({
        current = current.next(settings.num_pomodoros);
    }) {
        var timer = try std.time.Timer.start();
        const length = current.length(settings);

        while (timer.read() < length) {
            const remaining = length - timer.read();
            try printRemaining(
                allocator,
                stdout,
                current,
                settings.num_pomodoros,
                remaining,
            );

            _ = try poller.pollTimeout(std.time.ns_per_s) or break;
            if (poller.fifo(.stdin).readItem()) |char| {
                switch (char) {
                    'q' => {
                        try stdout.print("\n", .{});
                        return;
                    },
                    else => {},
                }
            }
        }
    }
}

fn printRemaining(
    allocator: std.mem.Allocator,
    out: std.fs.File.Writer,
    current: step.Step,
    num_pomodoros: u32,
    remaining: u64,
) !void {
    const msg = try current.render(allocator, num_pomodoros, remaining);
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
