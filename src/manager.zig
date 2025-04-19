const std = @import("std");
const settings = @import("settings.zig");
const view = @import("view.zig");
const dates = @import("dates.zig");
const builtin = @import("builtin");
const sdl = @import("sdl.zig").sdl;

pub var env_path: []u8 = undefined;
pub var env_dir: std.fs.Dir = undefined;

pub var gpallocator = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpallocator.allocator();

pub fn initApp() !void {
    env_path = if ((builtin.os.tag == .linux and !builtin.abi.isAndroid()) or builtin.os.tag == .windows) std.fs.getAppDataDir(allocator, "Epigeos/hydor/Reo") catch try std.fmt.allocPrint(allocator, "data", .{}) else std.mem.span(sdl.SDL_GetPrefPath("Epigeos", "Reo"));

    // Ensure all paths are there
    env_dir = try std.fs.cwd().makeOpenPath(env_path, .{});
    const readme = try env_dir.createFile("readBeforeEditingOrDeletingAnything.txt", .{ .truncate = false });
    if (try readme.getEndPos() == 0) {
        try readme.writeAll("General:\n  All files in here are regenerated if this file is detected missing, they're not emptied to avoid accidents\nFor events:\n  The first and last line of a file shall always be empty and all repeat formulae shall be all lowercase\n  Use // at the beginning of a line for comments");
        const events = try env_dir.createFile("events.data", .{ .truncate = false });
        try events.writeAll("\n");
        events.close();
        const complex_events = try env_dir.createFile("complexEvents.data", .{ .truncate = false });
        try complex_events.writeAll("\n");
        complex_events.close();
        const complex_simplified_events = try env_dir.createFile("complexEvents.simplified.data", .{ .truncate = false });
        try complex_simplified_events.writeAll("\n");
        complex_simplified_events.close();
        env_dir.makeDir("translations") catch undefined;
    }
    readme.close();

    view.current_jd = dates.now();
    try settings.loadSettings();
    view.loadCurrentSettingsIntoUI();
}
pub fn deinitApp() void {
    allocator.free(env_path);
    env_dir.close();

    // _ = gpallocator.detectLeaks();
    // _ = gpallocator.deinit();
}
pub fn appendFile(dir: std.fs.Dir, sub_path: []const u8, data: []const u8) !void {
    const file = try dir.openFile(sub_path, .{ .mode = .write_only });
    defer file.close();
    try file.seekFromEnd(0);
    var writer = file.writer();
    try writer.writeAll(data);
}
