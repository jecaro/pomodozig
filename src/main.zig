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

    // Print a placeholder to be cleared by the first status
    if (poller.interactive()) {
        try stdout.print("\n", .{});
    }

    var current = step.Step{};
    while (true) : ({
        current = current.next(settings.num_pomodoros);
        if (settings.notifications) {
            notify(allocator, current.step_type.message());
        }
    }) {
        var timer = try pausable_timer.PausableTimer.init();

        var remaining = current.length(settings);

        while (remaining > 0) : ({
            remaining = current.length(settings) -| timer.read();
        }) {
            // Clear the last status
            if (poller.interactive()) {
                try stdout.print("\x1b[F\x1b[2K\r", .{});
            }
            try printStatus(
                allocator,
                stdout,
                current,
                settings.num_pomodoros,
                remaining,
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
                        // if the step is not started yet
                        if (timer.paused and remaining == current.length(settings)) {
                            current = step.Step{};
                        }

                        try timer.reset();
                    },
                }
            }
        }
    }
}

fn notify(allocator: std.mem.Allocator, message: []const u8) void {
    const argv = [_][]const u8{ "notify-send", "pomodozig", message };
    var proc = std.process.Child.init(&argv, allocator);

    proc.spawn() catch {
        return;
    };

    _ = proc.wait() catch {};
}

fn printStatus(
    allocator: std.mem.Allocator,
    out: std.fs.File.Writer,
    current: step.Step,
    num_pomodoros: u32,
    remaining: u64,
) !void {
    const msg = try current.render(allocator, num_pomodoros, remaining);
    defer allocator.free(msg);

    try out.print("{s}\n", .{msg});
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
