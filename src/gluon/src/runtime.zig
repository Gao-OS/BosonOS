const std = @import("std");

const config = @import("config.zig");
const log = @import("log.zig");

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
    const term = try child.wait();

    return switch (term) {
        .Exited => |code| code,
        .Signal => |signal| 128 + @as(u8, @intCast(signal)),
        .Stopped => 1,
        .Unknown => 1,
    };
}

fn applyEnvironment(env_map: *std.process.EnvMap, cfg: config.Config) !void {
    try env_map.put("PATH", cfg.path);
    try env_map.put("HOME", cfg.home);
    try env_map.put("TERM", cfg.term);
    try env_map.put("RELEASE_TMP", cfg.release_tmp);
    try env_map.put("RELEASE_DISTRIBUTION", cfg.release_distribution);
}

test "runtime environment applies the init contract" {
    var env_map = std.process.EnvMap.init(std.testing.allocator);
    defer env_map.deinit();

    try applyEnvironment(&env_map, config.Config{});

    try std.testing.expectEqualStrings("/bin:/sbin", env_map.get("PATH").?);
    try std.testing.expectEqualStrings("/root", env_map.get("HOME").?);
    try std.testing.expectEqualStrings("linux", env_map.get("TERM").?);
    try std.testing.expectEqualStrings("/run/boson", env_map.get("RELEASE_TMP").?);
    try std.testing.expectEqualStrings("none", env_map.get("RELEASE_DISTRIBUTION").?);
}
