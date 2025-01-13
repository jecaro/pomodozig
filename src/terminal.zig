const std = @import("std");

/// Turn on these two options on stdin:
/// - ICANON: disable line buffering
/// - ECHO: disable echo
///
/// Used to be able to read a single character from stdin. Only works when
/// running in interactive mode
pub const Terminal = struct {
    termios: std.posix.termios,

    pub fn init() !Terminal {
        const old = try std.posix.tcgetattr(std.posix.STDIN_FILENO);
        var termios = old;
        // unbuffered input
        termios.lflag.ICANON = false;
        // no echo
        termios.lflag.ECHO = false;
        try std.posix.tcsetattr(std.posix.STDIN_FILENO, .NOW, termios);
        return .{ .termios = old };
    }

    pub fn deinit(self: Terminal) void {
        std.posix.tcsetattr(std.posix.STDIN_FILENO, .NOW, self.termios) catch unreachable;
    }
};
