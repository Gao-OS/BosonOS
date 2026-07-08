const config = @import("config.zig");
const log = @import("log.zig");

pub fn apply(cfg: config.Config) !void {
    if (cfg.mount_proc) log.info("mount requested: /proc", .{});
    if (cfg.mount_sys) log.info("mount requested: /sys", .{});
    if (cfg.mount_dev) log.info("mount requested: /dev", .{});
    if (cfg.mount_run) log.info("mount requested: /run", .{});
    if (cfg.mount_data) log.info("mount requested: {s}", .{cfg.data_mount});
}
