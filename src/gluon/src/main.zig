const std = @import("std");

const action = @import("action.zig");
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

    if (is_pid_one) {
        action.clearStale(action.path) catch |err| {
            log.err("could not clear stale runtime action: {s}", .{@errorName(err)});
            return reboot.apply(allocator, cfg.on_crash, cfg);
        };
    }

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

    if (exit_code != 0) {
        log.err("runtime exited with status {}", .{exit_code});
    }

    const file_state = if (exit_code == 0) action.consume(action.path) else blk: {
        action.clearStale(action.path) catch |err| {
            log.warn("could not discard runtime action after crash: {s}", .{@errorName(err)});
        };
        break :blk action.FileState.missing;
    };

    switch (file_state) {
        .invalid => log.err("invalid runtime action", .{}),
        .read_error => log.err("could not read runtime action", .{}),
        .remove_error => log.err("could not remove runtime action", .{}),
        .missing, .requested => {},
    }

    switch (action.decide(exit_code, file_state, cfg.on_exit, cfg.on_crash)) {
        .configured => |policy| try reboot.apply(allocator, policy, cfg),
        .requested => |requested| {
            log.info("applying runtime action: {s}", .{@tagName(requested)});
            try reboot.apply(allocator, action.toPolicy(requested), cfg);
        },
    }
}
