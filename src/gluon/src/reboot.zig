const config = @import("config.zig");
const log = @import("log.zig");

pub fn apply(policy: config.ExitPolicy, cfg: config.Config) !void {
    switch (policy) {
        .reboot => log.warn("exit policy requested reboot", .{}),
        .poweroff => log.warn("exit policy requested poweroff", .{}),
        .hang => log.warn("exit policy requested hang", .{}),
        .emergency_shell => log.warn("exit policy requested emergency shell: {s}", .{cfg.emergency_shell}),
    }
}
