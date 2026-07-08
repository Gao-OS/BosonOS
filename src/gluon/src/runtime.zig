const std = @import("std");

const config = @import("config.zig");
const log = @import("log.zig");

pub fn run(allocator: std.mem.Allocator, cfg: config.Config) !u8 {
    var argv = [_][]const u8{
        cfg.release_bin,
        cfg.release_command,
    };

    log.info("starting runtime: {s} {s}", .{ cfg.release_bin, cfg.release_command });

    var child = std.process.Child.init(&argv, allocator);
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
