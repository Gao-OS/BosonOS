const std = @import("std");

const cmdline = @import("cmdline.zig");
const config = @import("config.zig");
const console = @import("console.zig");
const log = @import("log.zig");
const mount = @import("mount.zig");
const reboot = @import("reboot.zig");
const runtime = @import("runtime.zig");
const signals = @import("signals.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    log.info("starting", .{});

    const is_pid_one = std.os.linux.getpid() == 1;
    if (!is_pid_one) {
        log.warn("running outside PID 1 diagnostic mode", .{});
    }

    try signals.install();

    var cfg = config.load(allocator, "/etc/gluon.conf");
    defer cfg.deinit(allocator);

    try mount.apply(cfg);

    const kernel_cmdline = cmdline.read(allocator, "/proc/cmdline") catch |err| blk: {
        log.warn("could not read /proc/cmdline: {s}", .{@errorName(err)});
        break :blk null;
    };
    defer if (kernel_cmdline) |buffer| allocator.free(buffer);

    if (kernel_cmdline) |buffer| {
        cmdline.observe(buffer);
    }

    try console.configure(cfg);

    const exit_code = runtime.run(allocator, cfg) catch |err| {
        log.err("runtime start failed: {s}", .{@errorName(err)});
        if (is_pid_one) try reboot.apply(allocator, cfg.on_crash, cfg);
        return err;
    };

    if (!is_pid_one) {
        log.info("runtime exited outside PID 1; machine policy skipped", .{});
        return;
    }

    if (exit_code == 0) {
        try reboot.apply(allocator, cfg.on_exit, cfg);
    } else {
        log.err("runtime exited with status {}", .{exit_code});
        try reboot.apply(allocator, cfg.on_crash, cfg);
    }
}
