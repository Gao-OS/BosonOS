const std = @import("std");

const log = @import("log.zig");

pub const ExitPolicy = enum {
    reboot,
    poweroff,
    hang,
    emergency_shell,
};

pub const Config = struct {
    storage: ?[]u8 = null,

    release_path: []const u8 = "/srv/boson",
    release_bin: []const u8 = "/srv/boson/bin/boson",
    release_command: []const u8 = "foreground",

    hostname: []const u8 = "boson",
    console: []const u8 = "/dev/console",

    mount_proc: bool = true,
    mount_sys: bool = true,
    mount_dev: bool = true,
    mount_run: bool = true,
    mount_data: bool = true,

    data_mount: []const u8 = "/data",
    on_exit: ExitPolicy = .reboot,
    on_crash: ExitPolicy = .reboot,
    emergency_shell: []const u8 = "/bin/sh",

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        if (self.storage) |buffer| {
            allocator.free(buffer);
            self.storage = null;
        }
    }
};

pub fn load(allocator: std.mem.Allocator, path: []const u8) Config {
    var cfg = Config{};

    var file = std.fs.openFileAbsolute(path, .{}) catch |err| {
        log.warn("using built-in config defaults: {s}", .{@errorName(err)});
        return cfg;
    };
    defer file.close();

    const buffer = file.readToEndAlloc(allocator, 64 * 1024) catch |err| {
        log.warn("could not read config, using defaults: {s}", .{@errorName(err)});
        return cfg;
    };

    cfg.storage = buffer;
    parse(&cfg, buffer);
    return cfg;
}

fn parse(cfg: *Config, buffer: []const u8) void {
    var lines = std.mem.tokenizeScalar(u8, buffer, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r\n");

        if (line.len == 0 or line[0] == '#') {
            continue;
        }

        const separator = std.mem.indexOfScalar(u8, line, '=') orelse {
            log.warn("ignoring config line without '='", .{});
            continue;
        };

        const key = std.mem.trim(u8, line[0..separator], " \t");
        const value = std.mem.trim(u8, line[separator + 1 ..], " \t");
        apply(cfg, key, value);
    }
}

fn apply(cfg: *Config, key: []const u8, value: []const u8) void {
    if (std.mem.eql(u8, key, "release_path")) {
        cfg.release_path = value;
    } else if (std.mem.eql(u8, key, "release_bin")) {
        cfg.release_bin = value;
    } else if (std.mem.eql(u8, key, "release_command")) {
        cfg.release_command = value;
    } else if (std.mem.eql(u8, key, "hostname")) {
        cfg.hostname = value;
    } else if (std.mem.eql(u8, key, "console")) {
        cfg.console = value;
    } else if (std.mem.eql(u8, key, "mount_proc")) {
        cfg.mount_proc = parseBool(value, cfg.mount_proc);
    } else if (std.mem.eql(u8, key, "mount_sys")) {
        cfg.mount_sys = parseBool(value, cfg.mount_sys);
    } else if (std.mem.eql(u8, key, "mount_dev")) {
        cfg.mount_dev = parseBool(value, cfg.mount_dev);
    } else if (std.mem.eql(u8, key, "mount_run")) {
        cfg.mount_run = parseBool(value, cfg.mount_run);
    } else if (std.mem.eql(u8, key, "mount_data")) {
        cfg.mount_data = parseBool(value, cfg.mount_data);
    } else if (std.mem.eql(u8, key, "data_mount")) {
        cfg.data_mount = value;
    } else if (std.mem.eql(u8, key, "on_exit")) {
        cfg.on_exit = parsePolicy(value, cfg.on_exit);
    } else if (std.mem.eql(u8, key, "on_crash")) {
        cfg.on_crash = parsePolicy(value, cfg.on_crash);
    } else if (std.mem.eql(u8, key, "emergency_shell")) {
        cfg.emergency_shell = value;
    } else {
        log.warn("ignoring unknown config key: {s}", .{key});
    }
}

fn parseBool(value: []const u8, fallback: bool) bool {
    if (std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "false")) return false;
    return fallback;
}

fn parsePolicy(value: []const u8, fallback: ExitPolicy) ExitPolicy {
    if (std.mem.eql(u8, value, "reboot")) return .reboot;
    if (std.mem.eql(u8, value, "poweroff")) return .poweroff;
    if (std.mem.eql(u8, value, "hang")) return .hang;
    if (std.mem.eql(u8, value, "emergency_shell")) return .emergency_shell;
    return fallback;
}
