const std = @import("std");

const Terminal = struct {
    termios: std.posix.termios,
    fd: std.posix.fd_t,
};

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

pub fn deinit(termios: Terminal) !void {
    try std.posix.tcsetattr(termios.fd, .NOW, termios.termios);
}
