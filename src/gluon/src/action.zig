const std = @import("std");
const config = @import("config.zig");

pub const path = "/run/boson/action";
pub const max_bytes = 16;

pub const Action = enum { reboot, poweroff };

pub const FileState = union(enum) {
    missing,
    requested: Action,
    invalid,
    read_error,
    remove_error,
};

pub const Decision = union(enum) {
    configured: config.ExitPolicy,
    requested: Action,
};

pub fn parse(payload: []const u8) ?Action {
    if (std.mem.eql(u8, payload, "reboot\n")) return .reboot;
    if (std.mem.eql(u8, payload, "poweroff\n")) return .poweroff;
    return null;
}

pub fn toPolicy(requested: Action) config.ExitPolicy {
    return switch (requested) {
        .reboot => .reboot,
        .poweroff => .poweroff,
    };
}

pub fn decide(
    exit_code: u8,
    file_state: FileState,
    on_exit: config.ExitPolicy,
    on_crash: config.ExitPolicy,
) Decision {
    if (exit_code != 0) return .{ .configured = on_crash };

    return switch (file_state) {
        .requested => |requested| .{ .requested = requested },
        .missing => .{ .configured = on_exit },
        .invalid, .read_error, .remove_error => .{ .configured = on_crash },
    };
}

const ProductionOps = struct {
    fn read(_: @This(), action_path: []const u8, buffer: []u8) !usize {
        var file = try std.fs.openFileAbsolute(action_path, .{});
        defer file.close();
        return file.readAll(buffer);
    }

    fn remove(_: @This(), action_path: []const u8) !void {
        return std.fs.deleteFileAbsolute(action_path);
    }
};

pub fn clearStale(action_path: []const u8) !void {
    return clearStaleWith(action_path, ProductionOps{});
}

fn clearStaleWith(action_path: []const u8, ops: anytype) !void {
    ops.remove(action_path) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
}

pub fn consume(action_path: []const u8) FileState {
    return consumeWith(action_path, ProductionOps{});
}

fn consumeWith(action_path: []const u8, ops: anytype) FileState {
    var buffer: [max_bytes + 1]u8 = undefined;
    const count = ops.read(action_path, &buffer) catch |err| switch (err) {
        error.FileNotFound => return .missing,
        else => {
            clearStaleWith(action_path, ops) catch return .remove_error;
            return .read_error;
        },
    };
    const requested = if (count > max_bytes) null else parse(buffer[0..count]);

    clearStaleWith(action_path, ops) catch return .remove_error;
    return if (requested) |value| .{ .requested = value } else .invalid;
}

test "parses only exact machine action payloads" {
    try std.testing.expectEqual(Action.reboot, parse("reboot\n").?);
    try std.testing.expectEqual(Action.poweroff, parse("poweroff\n").?);

    const invalid_payloads = [_][]const u8{
        "",                  "reboot",             "poweroff",   "\n",           "unknown\n",
        " reboot\n",         "reboot \n",          "reboot\r\n", "\treboot\n",   "reboot now\n",
        "poweroff now\n",    "reboot\npoweroff\n", "reboot\n\n", "reboot\x00\n", "poweroff\n\x00",
        "0123456789abcdefg",
    };
    for (invalid_payloads) |payload| {
        try std.testing.expect(parse(payload) == null);
    }
}

test "exit status and file state select the complete policy matrix" {
    const policies = std.enums.values(config.ExitPolicy);
    const states = [_]FileState{
        .missing,
        .{ .requested = .reboot },
        .{ .requested = .poweroff },
        .invalid,
        .read_error,
        .remove_error,
    };
    for (policies) |on_exit| {
        for (policies) |on_crash| {
            for (states) |file_state| {
                const clean = decide(0, file_state, on_exit, on_crash);
                switch (file_state) {
                    .requested => |requested| {
                        try std.testing.expectEqual(std.meta.Tag(Decision).requested, std.meta.activeTag(clean));
                        try std.testing.expectEqual(requested, clean.requested);
                    },
                    else => {
                        try std.testing.expectEqual(std.meta.Tag(Decision).configured, std.meta.activeTag(clean));
                        const expected = if (file_state == .missing) on_exit else on_crash;
                        try std.testing.expectEqual(expected, clean.configured);
                    },
                }
                for ([_]u8{ 1, 143, 255 }) |exit_code| {
                    const crashed = decide(exit_code, file_state, on_exit, on_crash);
                    try std.testing.expectEqual(std.meta.Tag(Decision).configured, std.meta.activeTag(crashed));
                    try std.testing.expectEqual(on_crash, crashed.configured);
                }
            }
        }
    }
}

fn temporaryActionPath(tmp: *std.testing.TmpDir) ![]u8 {
    const directory = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(directory);
    return std.fs.path.join(std.testing.allocator, &.{ directory, "action" });
}

test "missing action consumption and stale cleanup are harmless" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const action_path = try temporaryActionPath(&tmp);
    defer std.testing.allocator.free(action_path);

    try std.testing.expectEqual(FileState.missing, consume(action_path));
    try clearStale(action_path);
}

test "valid machine actions are consumed once and deleted" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const action_path = try temporaryActionPath(&tmp);
    defer std.testing.allocator.free(action_path);

    const cases = [_]struct { payload: []const u8, requested: Action }{
        .{ .payload = "reboot\n", .requested = .reboot },
        .{ .payload = "poweroff\n", .requested = .poweroff },
    };
    for (cases) |case| {
        try tmp.dir.writeFile(.{ .sub_path = "action", .data = case.payload });
        const state = consume(action_path);
        try std.testing.expectEqual(std.meta.Tag(FileState).requested, std.meta.activeTag(state));
        try std.testing.expectEqual(case.requested, state.requested);
        try std.testing.expectError(error.FileNotFound, tmp.dir.access("action", .{}));
        try std.testing.expectEqual(FileState.missing, consume(action_path));
    }
}

test "invalid and oversized actions are rejected and deleted" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const action_path = try temporaryActionPath(&tmp);
    defer std.testing.allocator.free(action_path);

    const oversized = [_]u8{'x'} ** 4096;
    for ([_][]const u8{ "", "unknown\n", "reboot now\n", "poweroff", &oversized }) |payload| {
        try tmp.dir.writeFile(.{ .sub_path = "action", .data = payload });
        try std.testing.expectEqual(FileState.invalid, consume(action_path));
        try std.testing.expectError(error.FileNotFound, tmp.dir.access("action", .{}));
    }
}

test "stale action is removed before runtime launch" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const action_path = try temporaryActionPath(&tmp);
    defer std.testing.allocator.free(action_path);

    try tmp.dir.writeFile(.{ .sub_path = "action", .data = "poweroff\n" });
    try clearStale(action_path);
    try std.testing.expectError(error.FileNotFound, tmp.dir.access("action", .{}));
}

const FakeOps = struct {
    const RemoveError = error{ FileNotFound, InjectedRemove };

    payload: []const u8 = "",
    missing: bool = false,
    fail_read: bool = false,
    fail_remove: bool = false,
    removed: bool = false,

    fn read(self: *@This(), _: []const u8, buffer: []u8) error{ FileNotFound, InjectedRead }!usize {
        if (self.missing) return error.FileNotFound;
        if (self.fail_read) return error.InjectedRead;
        const count = @min(self.payload.len, buffer.len);
        @memcpy(buffer[0..count], self.payload[0..count]);
        return count;
    }

    fn remove(self: *@This(), _: []const u8) RemoveError!void {
        if (self.fail_remove) return error.InjectedRemove;
        if (self.missing) return error.FileNotFound;
        self.removed = true;
    }
};

test "read failure still deletes the action before returning" {
    var fake = FakeOps{ .fail_read = true };
    try std.testing.expectEqual(FileState.read_error, consumeWith("/unused", &fake));
    try std.testing.expect(fake.removed);
}

test "read and removal failure selects removal error" {
    var fake = FakeOps{ .fail_read = true, .fail_remove = true };
    try std.testing.expectEqual(FileState.remove_error, consumeWith("/unused", &fake));
    try std.testing.expect(!fake.removed);
}

test "valid action cannot execute when removal fails" {
    var fake = FakeOps{ .payload = "poweroff\n", .fail_remove = true };
    try std.testing.expectEqual(FileState.remove_error, consumeWith("/unused", &fake));
    try std.testing.expect(!fake.removed);
}

test "invalid action removal failure selects removal error" {
    var fake = FakeOps{ .payload = "unknown\n", .fail_remove = true };
    try std.testing.expectEqual(FileState.remove_error, consumeWith("/unused", &fake));
}

test "stale cleanup propagates removal failure but accepts missing file" {
    var failure = FakeOps{ .fail_remove = true };
    try std.testing.expectError(error.InjectedRemove, clearStaleWith("/unused", &failure));

    var missing = FakeOps{ .missing = true };
    try clearStaleWith("/unused", &missing);
    try std.testing.expectEqual(FileState.missing, consumeWith("/unused", &missing));
    try std.testing.expect(!missing.removed);
}

test "requested actions map to machine policies" {
    try std.testing.expectEqual(config.ExitPolicy.reboot, toPolicy(.reboot));
    try std.testing.expectEqual(config.ExitPolicy.poweroff, toPolicy(.poweroff));
}
