const std = @import("std");

const log = @import("log.zig");

var pending_signal = std.atomic.Value(u8).init(0);

pub fn install() !void {
    const action: std.posix.Sigaction = .{
        .handler = .{ .handler = handle },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };

    std.posix.sigaction(std.posix.SIG.TERM, &action, null);
    std.posix.sigaction(std.posix.SIG.INT, &action, null);
    std.posix.sigaction(std.posix.SIG.HUP, &action, null);
    log.info("signal policy installed", .{});
}

pub fn take() ?u8 {
    const signal_number = pending_signal.swap(0, .acquire);
    return if (signal_number == 0) null else signal_number;
}

fn handle(signal_number: i32) callconv(.c) void {
    if (signal_number <= 0 or signal_number > std.math.maxInt(u8)) return;
    record(@intCast(signal_number));
}

fn record(signal_number: u8) void {
    pending_signal.store(signal_number, .release);
}

test "a pending signal is consumed once" {
    record(std.posix.SIG.TERM);

    try std.testing.expectEqual(@as(?u8, std.posix.SIG.TERM), take());
    try std.testing.expectEqual(@as(?u8, null), take());
}
