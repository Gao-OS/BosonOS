const config = @import("config.zig");
const log = @import("log.zig");

pub fn configure(cfg: config.Config) !void {
    log.info("console configured: {s}", .{cfg.console});
    log.info("hostname configured: {s}", .{cfg.hostname});
}
