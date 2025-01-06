const std = @import("std");
const options = @import("options.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    const program_and_args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, program_and_args);

    const program: []const u8 = program_and_args[0];
    const args: [][]const u8 = program_and_args[1..];

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
            std.debug.print("args: {}\n", .{opts});
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
