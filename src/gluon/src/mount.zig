const std = @import("std");

const config = @import("config.zig");
const log = @import("log.zig");

const linux = std.os.linux;

pub fn apply(cfg: config.Config) !void {
    if (cfg.mount_proc) {
        try mountOne("proc", "/proc", "proc", linux.MS.NOSUID | linux.MS.NODEV | linux.MS.NOEXEC, null);
    }
    if (cfg.mount_sys) {
        try mountOne("sysfs", "/sys", "sysfs", linux.MS.NOSUID | linux.MS.NODEV | linux.MS.NOEXEC, null);
    }
    if (cfg.mount_dev) {
        try mountOne("devtmpfs", "/dev", "devtmpfs", linux.MS.NOSUID, "mode=0755");
    }
    if (cfg.mount_run) {
        try mountOne("tmpfs", "/run", "tmpfs", linux.MS.NOSUID | linux.MS.NODEV, "mode=0755");
    }
    if (cfg.mount_data) {
        log.warn("optional data mount deferred: no data device is configured for {s}", .{cfg.data_mount});
    }
}

fn mountOne(
    source: [*:0]const u8,
    target: [*:0]const u8,
    filesystem: [*:0]const u8,
    flags: u32,
    data: ?[*:0]const u8,
) !void {
    const result = linux.mount(
        source,
        target,
        filesystem,
        flags,
        if (data) |value| @intFromPtr(value) else 0,
    );
    try checkMountResult(linux.E.init(result));
    log.info("mounted {s} on {s}", .{ filesystem, target });
}

fn checkMountResult(result: linux.E) !void {
    return switch (result) {
        .SUCCESS, .BUSY => {},
        .PERM, .ACCES => error.PermissionDenied,
        .NOENT => error.MountPointNotFound,
        .INVAL => error.InvalidMount,
        .NODEV => error.FileSystemUnavailable,
        .ROFS => error.ReadOnlyFileSystem,
        else => error.MountFailed,
    };
}

test "mount result accepts success and an existing mount" {
    try checkMountResult(.SUCCESS);
    try checkMountResult(.BUSY);
}

test "mount result reports permission failures" {
    try std.testing.expectError(error.PermissionDenied, checkMountResult(.PERM));
}
