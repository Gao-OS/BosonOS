const std = @import("std");

const config = @import("config.zig");
const log = @import("log.zig");

pub fn apply(
    allocator: std.mem.Allocator,
    policy: config.ExitPolicy,
    cfg: config.Config,
) !void {
    switch (policy) {
        .reboot => {
            log.warn("exit policy requested reboot", .{});
            std.posix.sync();
            try std.posix.reboot(.RESTART);
            hang();
        },
        .poweroff => {
            log.warn("exit policy requested poweroff", .{});
            std.posix.sync();
            try std.posix.reboot(.POWER_OFF);
            hang();
        },
        .hang => {
            log.warn("exit policy requested hang", .{});
            hang();
        },
        .emergency_shell => {
            log.warn("exit policy requested emergency shell: {s}", .{cfg.emergency_shell});
            var argv = [_][]const u8{cfg.emergency_shell};
            var child = std.process.Child.init(&argv, allocator);
            child.stdin_behavior = .Inherit;
            child.stdout_behavior = .Inherit;
            child.stderr_behavior = .Inherit;
            try child.spawn();
            _ = try child.wait();
            hang();
        },
    }
}

fn hang() noreturn {
    while (true) std.Thread.sleep(std.time.ns_per_s);
}
