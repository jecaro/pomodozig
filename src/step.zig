const options = @import("options.zig");
const std = @import("std");

pub const StepType = enum(u8) {
    task = 'T',
    short_break = 'S',
    long_break = 'L',
};

pub const Step = struct {
    task: u32 = 1,
    step_type: StepType = StepType.task,

    pub fn next(self: Step, num_pomodoros: u32) Step {
        return switch (self.step_type) {
            StepType.task => Step{
                .task = self.task,
                .step_type = if (self.task % num_pomodoros == 0)
                    StepType.long_break
                else
                    StepType.short_break,
            },
            StepType.short_break, StepType.long_break => Step{
                .task = self.task + 1,
                .step_type = StepType.task,
            },
        };
    }

    pub fn length(self: Step, settings: options.Settings) u64 {
        const minutes: u64 = switch (self.step_type) {
            StepType.task => settings.task_length,
            StepType.short_break => settings.short_break,
            StepType.long_break => settings.long_break,
        };

        return minutes * std.time.ns_per_min;
    }

    pub fn render(
        self: Step,
        allocator: std.mem.Allocator,
        num_pomodoros: u32,
        countdown: u64,
        paused: bool,
    ) ![]u8 {
        return try std.fmt.allocPrint(
            allocator,
            "{c}-{}/{}-{c}-{}",
            .{
                @as(u8, if (paused) 'P' else 'R'),
                self.task,
                num_pomodoros,
                @intFromEnum(self.step_type),
                countdown / std.time.ns_per_s,
            },
        );
    }
};
