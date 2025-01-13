const options = @import("options.zig");
const std = @import("std");

pub const StepType = enum(u8) {
    task = 'T',
    short_break = 'b',
    long_break = 'B',

    pub fn message(self: StepType) []const u8 {
        return switch (self) {
            StepType.task => "Time to focus!",
            StepType.short_break => "Time for a break!",
            StepType.long_break => "Time for a long break!",
        };
    }
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
    ) ![]u8 {
        const total_secs = countdown / std.time.ns_per_s;
        const mins = total_secs / std.time.s_per_min;
        const secs = total_secs % std.time.s_per_min;
        return try std.fmt.allocPrint(
            allocator,
            "{c}-{}/{}-{:0>2}:{:0>2}",
            .{
                @intFromEnum(self.step_type),
                self.task,
                num_pomodoros,
                mins,
                secs,
            },
        );
    }
};
