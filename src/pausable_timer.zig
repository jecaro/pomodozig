const std = @import("std");

pub const PausableTimer = struct {
    timer: std.time.Timer,
    paused: bool,

    pub fn init() !PausableTimer {
        return PausableTimer{
            .timer = try std.time.Timer.start(),
            .paused = true,
        };
    }

    pub fn togglePause(self: *PausableTimer) !void {
        // when restarting we offset the started field of the time of the time
        // that has passed since the pause started
        if (self.paused) {
            //        running         paused
            //    |-------------|----------------|
            // started      previous             now
            const now = try std.time.Instant.now();
            const since_paused_nsec: u64 = now.since(self.timer.previous);
            self.timer.started = add_ns(
                self.timer.started,
                since_paused_nsec,
            );
        }
        self.paused = !self.paused;
    }

    pub fn reset(self: *PausableTimer) !void {
        if (!self.paused) {
            try self.togglePause();
        }
        self.timer.reset();
    }

    pub fn read(self: *PausableTimer) u64 {
        if (self.paused) {
            // make as if the timer was paused
            return self.timer.previous.since(self.timer.started);
        } else {
            return self.timer.read();
        }
    }
};

pub fn add_ns(instant: std.time.Instant, offset_nsec: u64) std.time.Instant {
    // timestamp is expressed in seconds and nanoseconds. we add the offset to
    // the nanoseconds part
    const instant_tv_nsec: u64 = @intCast(instant.timestamp.tv_nsec);
    const total_tv_nsec: u64 = instant_tv_nsec + offset_nsec;

    // then we split the result in the new nanosecond part
    const new_ns: u64 = total_tv_nsec % std.time.ns_per_s;
    // and the number of seconds to add to the second part
    const elapsed_sec: u64 = total_tv_nsec / std.time.ns_per_s;

    return .{ .timestamp = .{
        .tv_sec = instant.timestamp.tv_sec + @as(isize, @intCast(elapsed_sec)),
        .tv_nsec = @intCast(new_ns),
    } };
}
