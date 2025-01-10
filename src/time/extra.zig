const std = @import("std");

pub fn add_ns(instant: std.time.Instant, offset_nsec: u64) std.time.Instant {
    // timestamp is expressed in seconds and nanoseconds. we add the offset to
    // the nanoseconds part
    const instant_tv_nsec: u64 = @intCast(instant.timestamp.tv_nsec);
    const total_tv_nsec: u64 = instant_tv_nsec + offset_nsec;

    // then we split the result in the new nanosecond part
    const new_ns: u64 = total_tv_nsec % std.time.ns_per_s;
    // and the number of seconds to add to the second part
    const elapsed_sec: u64 = total_tv_nsec / std.time.ns_per_s;

    // return new;
    return .{ .timestamp = .{
        .tv_sec = instant.timestamp.tv_sec + @as(isize, @intCast(elapsed_sec)),
        .tv_nsec = @intCast(new_ns),
    } };
}

pub fn read_paused(timer: *std.time.Timer, paused: bool) u64 {
    if (paused) {
        // make as it the timer was paused
        return timer.previous.since(timer.started);
    } else {
        return timer.read();
    }
}
