const std = @import("std");

pub fn info(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("gluon info: " ++ fmt ++ "\n", args);
}

pub fn warn(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("gluon warn: " ++ fmt ++ "\n", args);
}

pub fn err(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("gluon error: " ++ fmt ++ "\n", args);
}
