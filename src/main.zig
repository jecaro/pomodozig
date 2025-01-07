const std = @import("std");
const options = @import("options.zig");

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
        .settings => {
            try setUnbufferedAndNoEcho(std.posix.STDIN_FILENO);
            const stdin = std.io.getStdIn().reader();

            try stdout.print("Settings: {}\n", .{opts});
            while (true) {
                try stdout.print("Hit a key to start\n", .{});
                _ = try stdin.readByte();
            }
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

fn setUnbufferedAndNoEcho(fd: std.posix.fd_t) !void {
    var termios = try std.posix.tcgetattr(fd);
    // unbuffered input
    termios.lflag.ICANON = false;
    // no echo
    termios.lflag.ECHO = false;
    try std.posix.tcsetattr(fd, .NOW, termios);
}
