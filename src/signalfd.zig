const std = @import("std");

pub fn read(fifo: *std.io.PollFifo) !?std.os.linux.signalfd_siginfo {
    if (fifo.readableLength() < @sizeOf(std.os.linux.signalfd_siginfo)) {
        return null;
    }

    var siginfo: std.os.linux.signalfd_siginfo = undefined;
    const num_bytes = fifo.read(std.mem.asBytes(&siginfo));

    if (num_bytes < @sizeOf(std.os.linux.signalfd_siginfo)) {
        return error.ShortRead;
    }

    return siginfo;
}

pub fn open() !std.fs.File {
    var mask = std.posix.empty_sigset;
    std.os.linux.sigaddset(&mask, std.os.linux.SIG.USR1);
    std.os.linux.sigaddset(&mask, std.os.linux.SIG.USR2);

    _ = std.os.linux.sigprocmask(std.os.linux.SIG.BLOCK, &mask, null);
    return .{
        .handle = @intCast(
            std.os.linux.signalfd(
                -1,
                &mask,
                std.os.linux.SFD.NONBLOCK,
            ),
        ),
    };
}
