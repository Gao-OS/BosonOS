const std = @import("std");

const config = @import("config.zig");
const log = @import("log.zig");
const signals = @import("signals.zig");

const linux = std.os.linux;
const posix = std.posix;

pub fn run(allocator: std.mem.Allocator, cfg: config.Config) !u8 {
    var argv = [_][]const u8{
        cfg.release_bin,
        cfg.release_command,
    };

    log.info("starting runtime: {s} {s}", .{ cfg.release_bin, cfg.release_command });

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();
    try applyEnvironment(&env_map, cfg);

    var child = std.process.Child.init(&argv, allocator);
    child.env_map = &env_map;
    child.cwd = cfg.release_path;
    child.pgid = 0;
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    try child.spawn();
    return waitForRuntime(child.id);
}

fn applyEnvironment(env_map: *std.process.EnvMap, cfg: config.Config) !void {
    try env_map.put("PATH", cfg.path);
    try env_map.put("HOME", cfg.home);
    try env_map.put("TERM", cfg.term);
    try env_map.put("LANG", cfg.lang);
    try env_map.put("RELEASE_TMP", cfg.release_tmp);
    try env_map.put("RELEASE_DISTRIBUTION", cfg.release_distribution);
}

fn waitForRuntime(runtime_pid: posix.pid_t) !u8 {
    while (true) {
        if (signals.take()) |signal_number| {
            try forwardSignal(runtime_pid, signal_number);
        }

        var status: u32 = 0;
        const result = linux.waitpid(-1, &status, 0);
        switch (linux.E.init(result)) {
            .SUCCESS => {
                const reaped_pid: posix.pid_t = @intCast(result);
                if (reaped_pid == runtime_pid) {
                    reapAvailableChildren();
                    return exitCodeFromStatus(status);
                }

                log.info("reaped adopted child {}", .{reaped_pid});
            },
            .INTR => continue,
            .CHILD => return error.RuntimeChildMissing,
            else => return error.WaitFailed,
        }
    }
}

fn forwardSignal(runtime_pid: posix.pid_t, signal_number: u8) !void {
    posix.kill(-runtime_pid, signal_number) catch |err| switch (err) {
        error.ProcessNotFound => return,
        else => return err,
    };
    log.info("forwarded signal {} to runtime", .{signal_number});
}

fn reapAvailableChildren() void {
    while (true) {
        var status: u32 = 0;
        const result = linux.waitpid(-1, &status, linux.W.NOHANG);
        switch (linux.E.init(result)) {
            .SUCCESS => if (result == 0) return,
            .CHILD => return,
            .INTR => continue,
            else => return,
        }
    }
}

fn exitCodeFromStatus(status: u32) u8 {
    if (posix.W.IFEXITED(status)) return posix.W.EXITSTATUS(status);
    if (posix.W.IFSIGNALED(status)) {
        return @intCast(128 + posix.W.TERMSIG(status));
    }
    return 1;
}

test "runtime environment applies the init contract" {
    var env_map = std.process.EnvMap.init(std.testing.allocator);
    defer env_map.deinit();

    try applyEnvironment(&env_map, config.Config{});

    try std.testing.expectEqualStrings("/bin:/sbin", env_map.get("PATH").?);
    try std.testing.expectEqualStrings("/root", env_map.get("HOME").?);
    try std.testing.expectEqualStrings("linux", env_map.get("TERM").?);
    try std.testing.expectEqualStrings("C.UTF-8", env_map.get("LANG").?);
    try std.testing.expectEqualStrings("/run/boson", env_map.get("RELEASE_TMP").?);
    try std.testing.expectEqualStrings("none", env_map.get("RELEASE_DISTRIBUTION").?);
}

test "linux wait status maps to runtime exit codes" {
    try std.testing.expectEqual(@as(u8, 0), exitCodeFromStatus(0));
    try std.testing.expectEqual(@as(u8, 7), exitCodeFromStatus(7 << 8));
    try std.testing.expectEqual(@as(u8, 143), exitCodeFromStatus(15));
}
