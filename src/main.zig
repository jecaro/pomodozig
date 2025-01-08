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
        try printUsage(allocator, program, stdout);
        std.process.exit(1);

        return;
    };

    switch (opts) {
        .help => {
            try printUsage(allocator, program, stdout);
        },
        .settings => |settings| {
            const term = try terminal.init(std.posix.STDIN_FILENO);
            const stdin = std.io.getStdIn().reader();

            try stdout.print("Settings: {}\n", .{opts});

            var current_step = step.Step{};
            while (true) : ({
                current_step = current_step.next(settings.num_pomodoros);
            }) {
                _ = try stdin.readByte();

                var timer = try std.time.Timer.start();
                const length = current_step.length(settings);

                while (timer.read() < length) {
                    const remaining = length - timer.read();
                    const msg = try step.render(
                        allocator,
                        current_step,
                        settings.num_pomodoros,
                        remaining,
                    );
                    defer allocator.free(msg);

                    try stdout.print("{s}", .{msg});

                    std.time.sleep(std.time.ns_per_s);

                    try stdout.print("\x1b[2K\r", .{});
                }
            }

            try terminal.deinit(term);
        },
    }
}

fn printUsage(
    allocator: std.mem.Allocator,
    program: []const u8,
    out: std.fs.File.Writer,
) !void {
    const usage = try options.usage(allocator, program);
    defer allocator.free(usage);

    try out.print("{s}", .{usage});
}
