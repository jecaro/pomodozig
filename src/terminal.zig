const std = @import("std");

/// Turn on these two options on the given fd:
/// - ICANON: disable line buffering
/// - ECHO: disable echo
pub const Terminal = struct {
    termios: std.posix.termios,
    fd: std.posix.fd_t,

    pub fn init(fd: std.posix.fd_t) !Terminal {
        const old = try std.posix.tcgetattr(fd);
        var termios = old;
        // unbuffered input
        termios.lflag.ICANON = false;
        // no echo
        termios.lflag.ECHO = false;
        try std.posix.tcsetattr(fd, .NOW, termios);
        return .{ .termios = old, .fd = fd };
    }

    pub fn deinit(self: Terminal) void {
        std.posix.tcsetattr(self.fd, .NOW, self.termios) catch unreachable;
    }
};
