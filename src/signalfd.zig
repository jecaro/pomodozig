const std = @import("std");

pub fn open() !std.fs.File {
    var mask = std.posix.sigemptyset();
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
