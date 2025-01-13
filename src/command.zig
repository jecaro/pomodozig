const signalfd = @import("signalfd.zig");
const std = @import("std");
const terminal = @import("terminal.zig");

pub const Command = enum {
    Pause,
    Quit,
    Reset,
};

const FdType = enum { stdin, signalfd };

pub const Poller = struct {
    poller: std.io.Poller(FdType),
    signalfd: std.fs.File,
    terminal: terminal.Terminal,

    pub fn init(allocator: std.mem.Allocator) !Poller {
        const terminal_ = try terminal.Terminal.init(std.posix.STDIN_FILENO);
        errdefer terminal.deinit();

        const signalfd_ = try signalfd.open();
        errdefer signalfd_.close();

        return Poller{
            .terminal = terminal_,
            .signalfd = signalfd_,
            .poller = std.io.poll(
                allocator,
                FdType,
                .{
                    .stdin = std.io.getStdIn(),
                    .signalfd = signalfd_,
                },
            ),
        };
    }

    pub fn deinit(self: *Poller) void {
        self.poller.deinit();
        self.terminal.deinit();
        self.signalfd.close();
    }

    pub fn pollTimeout(self: *Poller, nanoseconds: u64) !?Command {
        _ = try self.poller.pollTimeout(nanoseconds) or return error.Interrupted;

        if (self.poller.fifo(.stdin).readItem()) |char| {
            switch (char) {
                'p' => return Command.Pause,
                'q' => return Command.Quit,
                'r' => return Command.Reset,
                else => {},
            }
        }

        if (try signalfd.read(self.poller.fifo(.signalfd))) |siginfo| {
            switch (siginfo.signo) {
                std.os.linux.SIG.USR1 => return Command.Pause,
                std.os.linux.SIG.USR2 => return Command.Reset,
                else => unreachable,
            }
        }

        return null;
    }
};
