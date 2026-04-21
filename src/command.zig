const signalfd = @import("signalfd.zig");
const std = @import("std");
const terminal = @import("terminal.zig");

pub const Command = enum {
    Pause,
    Quit,
    Reset,
};

pub const Poller = struct {
    signalfd: std.posix.fd_t,
    /// Option set to the terminal, is null when running in non-interactive mode
    terminal: ?terminal.Terminal,

    pub fn init() !Poller {
        const opt_terminal = terminal.Terminal.init() catch null;
        errdefer {
            if (opt_terminal) |terminal_| {
                terminal_.deinit();
            }
        }

        const signalfd_ = try signalfd.open();
        errdefer _ = std.os.linux.close(signalfd_);

        return Poller{
            .terminal = opt_terminal,
            .signalfd = signalfd_,
        };
    }

    pub fn interactive(self: *Poller) bool {
        return self.terminal != null;
    }

    pub fn deinit(self: *Poller) void {
        if (self.terminal) |terminal_| terminal_.deinit();
        _ = std.os.linux.close(self.signalfd);
    }

    pub fn pollTimeout(self: *Poller, nanoseconds: u64) !?Command {
        // in non-interactive mode, we shouldn't poll stdin as it will always
        // be ready and cause a busy loop. Use -1 as fd to ignore it.
        const stdin_fd: std.posix.fd_t = if (self.terminal != null) std.posix.STDIN_FILENO else -1;
        var fds = [_]std.posix.pollfd{
            .{ .fd = stdin_fd, .events = std.os.linux.POLL.IN, .revents = 0 },
            .{ .fd = self.signalfd, .events = std.os.linux.POLL.IN, .revents = 0 },
        };

        const timeout_ms: i32 = @intCast(nanoseconds / std.time.ns_per_ms);
        const ready = try std.posix.poll(&fds, timeout_ms);

        if (ready == 0) return null;

        // Check stdin
        if (fds[0].revents & std.os.linux.POLL.IN != 0) {
            var buf: [1]u8 = undefined;
            const n = try std.posix.read(std.posix.STDIN_FILENO, &buf);
            if (n > 0) {
                switch (buf[0]) {
                    'p' => return Command.Pause,
                    'q' => return Command.Quit,
                    'r' => return Command.Reset,
                    else => {},
                }
            }
        }

        // Check signalfd
        if (fds[1].revents & std.os.linux.POLL.IN != 0) {
            var siginfo: std.os.linux.signalfd_siginfo = undefined;
            const bytes = try std.posix.read(self.signalfd, std.mem.asBytes(&siginfo));
            if (bytes == @sizeOf(std.os.linux.signalfd_siginfo)) {
                switch (siginfo.signo) {
                    @intFromEnum(std.os.linux.SIG.USR1) => return Command.Pause,
                    @intFromEnum(std.os.linux.SIG.USR2) => return Command.Reset,
                    else => unreachable,
                }
            }
        }

        return null;
    }
};
