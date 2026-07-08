const std = @import("std");

const log = @import("log.zig");

pub fn read(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();
    return file.readToEndAlloc(allocator, 64 * 1024);
}

pub fn observe(buffer: []const u8) void {
    const trimmed = std.mem.trim(u8, buffer, " \t\r\n");

    if (trimmed.len == 0) {
        log.warn("kernel command line is empty", .{});
        return;
    }

    if (hasToken(trimmed, "single")) {
        log.warn("single-user command line token observed", .{});
    }
}

fn hasToken(buffer: []const u8, token: []const u8) bool {
    var parts = std.mem.tokenizeAny(u8, buffer, " \t\r\n");
    while (parts.next()) |part| {
        if (std.mem.eql(u8, part, token)) {
            return true;
        }
    }

    return false;
}
