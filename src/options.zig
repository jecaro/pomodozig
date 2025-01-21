const std = @import("std");

pub const OptionsTag = enum { settings, help };

pub const Options = union(OptionsTag) {
    settings: Settings,
    help: void,
};

pub const Settings = struct {
    /// Length of a task in minutes
    task_length: u32 = 25,
    /// Length of a short break in minutes
    short_break: u32 = 5,
    /// Number of pomodoros before a long break
    num_pomodoros: u32 = 4,
    /// Length of a long break in minutes
    long_break: u32 = 15,
    /// Enable notifications
    notifications: bool = true,
};

pub fn parseArgs(args: []const []const u8) !Options {
    var settings = Settings{};

    var i: u32 = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        // settings options
        if (i + 1 < args.len and std.mem.eql(u8, arg, "-t")) {
            i += 1;
            settings.task_length = try std.fmt.parseInt(u32, args[i], 10);
        } else if (i + 1 < args.len and std.mem.eql(u8, arg, "-sb")) {
            i += 1;
            settings.short_break = try std.fmt.parseInt(u32, args[i], 10);
        } else if (i + 1 < args.len and std.mem.eql(u8, arg, "-n")) {
            i += 1;
            settings.num_pomodoros = try std.fmt.parseInt(u32, args[i], 10);
        } else if (i + 1 < args.len and std.mem.eql(u8, arg, "-lb")) {
            i += 1;
            settings.long_break = try std.fmt.parseInt(u32, args[i], 10);
        } else if (std.mem.eql(u8, arg, "-s")) {
            settings.notifications = false;
        }
        // help
        else if (std.mem.eql(u8, arg, "-h")) {
            return .{ .help = void{} };
        }
        // error
        else {
            return error.InvalidArgument;
        }
    }

    return .{ .settings = settings };
}

pub fn usage(allocator: std.mem.Allocator, program: []const u8) ![]u8 {
    const result = try std.fmt.allocPrint(allocator,
        \\Usage: {s}
        \\[-t <task_length>]    Task length in minutes (default: 25 mins)
        \\[-sb <short_break>]   Short break length in minutes (default: 5 mins)
        \\[-n <num_pomodoros>]  Number of pomodoros before long break (default: 4)
        \\[-lb <long_break>]    Long break length in minutes (default: 15 mins)
        \\[-s]                  Disable notifications
        \\[-h]                  Show this help message
        \\
    , .{program});

    return result;
}

test "parseArgs options" {
    const args = [_][]const u8{
        "-t",  "30",
        "-sb", "10",
        "-n",  "5",
        "-lb", "20",
        "-s",
    };

    const options = try parseArgs(&args);
    try std.testing.expectEqual(options.settings.task_length, 30);
    try std.testing.expectEqual(options.settings.short_break, 10);
    try std.testing.expectEqual(options.settings.num_pomodoros, 5);
    try std.testing.expectEqual(options.settings.long_break, 20);
    try std.testing.expectEqual(options.settings.notifications, false);
}

test "parseArgs help" {
    const args = [_][]const u8{"-h"};

    const options = try parseArgs(&args);
    try std.testing.expectEqual(options, OptionsTag.help);
}

test "parseArgs nok" {
    const args = [_][]const u8{ "some", "junk", "arguments" };

    const result = parseArgs(&args);
    try std.testing.expectError(error.InvalidArgument, result);
}
