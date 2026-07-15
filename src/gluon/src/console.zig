const std = @import("std");

const config = @import("config.zig");
const log = @import("log.zig");

const linux = std.os.linux;
const posix = std.posix;

pub fn configure(cfg: config.Config) !void {
    try setHostname(cfg.hostname);

    const console_fd = try posix.open(
        cfg.console,
        .{ .ACCMODE = .RDWR, .NOCTTY = true },
        0,
    );
    defer if (console_fd > posix.STDERR_FILENO) posix.close(console_fd);

    try posix.dup2(console_fd, posix.STDIN_FILENO);
    try posix.dup2(console_fd, posix.STDOUT_FILENO);
    try posix.dup2(console_fd, posix.STDERR_FILENO);

    log.info("console configured: {s}", .{cfg.console});
    log.info("hostname configured: {s}", .{cfg.hostname});
}

fn setHostname(hostname: []const u8) !void {
    const result = linux.syscall2(
        .sethostname,
        @intFromPtr(hostname.ptr),
        hostname.len,
    );

    return switch (linux.E.init(result)) {
        .SUCCESS => {},
        .PERM, .ACCES => error.PermissionDenied,
        .INVAL, .NAMETOOLONG => error.InvalidHostname,
        else => error.SetHostnameFailed,
    };
}
