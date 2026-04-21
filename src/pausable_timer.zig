const std = @import("std");
const linux = std.os.linux;

fn now() linux.timespec {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(.MONOTONIC, &ts);
    return ts;
}

fn toNs(ts: linux.timespec) u64 {
    const sec: u64 = @intCast(ts.sec);
    const nsec: u64 = @intCast(ts.nsec);

    return sec * std.time.ns_per_s + nsec;
}

fn diffNs(a: linux.timespec, b: linux.timespec) u64 {
    return toNs(a) -| toNs(b);
}

pub const PausableTimer = struct {
    elapsed: u64,
    resumed_at: linux.timespec,
    paused: bool,

    pub fn init() PausableTimer {
        return .{ .elapsed = 0, .resumed_at = undefined, .paused = true };
    }

    pub fn togglePause(self: *PausableTimer) void {
        if (self.paused) {
            self.resumed_at = now();
        } else {
            self.elapsed += diffNs(now(), self.resumed_at);
        }
        self.paused = !self.paused;
    }

    pub fn reset(self: *PausableTimer) void {
        self.elapsed = 0;
        self.paused = true;
    }

    pub fn read(self: *PausableTimer) u64 {
        if (self.paused) {
            return self.elapsed;
        } else {
            return self.elapsed + diffNs(now(), self.resumed_at);
        }
    }
};
