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
    /// Option set to the terminal, is null when running in non-interactive mode
    terminal: ?terminal.Terminal,

    pub fn init(allocator: std.mem.Allocator) !Poller {
        const opt_terminal = terminal.Terminal.init() catch null;
        errdefer {
            if (opt_terminal) |terminal_| {
                terminal_.deinit();
            }
        }

        const signalfd_ = try signalfd.open();
        errdefer signalfd_.close();

        return Poller{
            .terminal = opt_terminal,
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

    pub fn interactive(self: *Poller) bool {
        return self.terminal != null;
    }

    pub fn deinit(self: *Poller) void {
        self.poller.deinit();
        if (self.terminal) |terminal_| terminal_.deinit();
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
