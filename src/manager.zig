const std = @import("std");
const settings = @import("settings.zig");
const view = @import("view.zig");
const dates = @import("dates.zig");
const builtin = @import("builtin");

pub var env_path: []u8 = undefined;
pub var env_dir: std.fs.Dir = undefined;

pub var gpallocator = std.heap.DebugAllocator(.{}).init;
pub const allocator = gpallocator.allocator();
pub var http_client = std.http.Client{ .allocator = allocator };

pub var installed_translation_options: ?[][]const u8 = null;
pub var not_installed_translation_options: ?[][]const u8 = null;
var dictionary_english: ?[][]const u8 = null;
var dictionary_translated: ?[][]const u8 = null;

pub fn initApp() !void {
    env_path = if ((builtin.os.tag == .linux and !builtin.abi.isAndroid()) or builtin.os.tag == .windows) std.fs.getAppDataDir(allocator, "Epigeos/hydor/Reo") catch try std.fmt.allocPrint(allocator, "data", .{}) else view.getPrefPath();

    // Generate any missing files
    env_dir = try std.fs.cwd().makeOpenPath(env_path, .{});
    const readme = try env_dir.createFile("README.md", .{ .truncate = false });
    if (try readme.getEndPos() == 0) {
        try readme.writeAll("Events:\n  The first and last line of a file shall always be empty and all repeat formulae shall be all lowercase\n  Use // at the beginning of a line for comments");
    }
    readme.close();
    const simple_events = try env_dir.createFile("simple.reoev", .{ .truncate = false });
    if (try simple_events.getEndPos() == 0) {
        try simple_events.writeAll("\n");
    }
    simple_events.close();
    const complex_events = try env_dir.createFile("complex.reoev", .{ .truncate = false });
    if (try complex_events.getEndPos() == 0) {
        try complex_events.writeAll("\n");
    }
    complex_events.close();
    const simplified_events = try env_dir.createFile("simplified.reoev", .{ .truncate = false });
    if (try simplified_events.getEndPos() == 0) {
        try simplified_events.writeAll("\n");
    }
    simplified_events.close();
    const settings_file = try env_dir.createFile("reo.cnf", .{ .truncate = false });
    if (try complex_events.getEndPos() == 0) {
        try settings.saveSettings();
    }
    settings_file.close();
    env_dir.makeDir("translations") catch |err| if (err != error.PathAlreadyExists) return err;
    refreshTranslationOptions() catch |err| std.debug.print("Error fetching translation options: {}\n", .{err});

    view.current_jd = dates.now();
    try settings.loadSettings();
}
pub fn deinitApp() void {
    if (installed_translation_options != null) {
        for (installed_translation_options.?) |element| allocator.free(element);
        allocator.free(installed_translation_options.?);
    }
    if (dictionary_english != null) {
        for (dictionary_english.?) |element| allocator.free(element);
        for (dictionary_translated.?) |element| allocator.free(element);
        allocator.free(dictionary_english.?);
        allocator.free(dictionary_translated.?);
    }
    allocator.free(env_path);
    env_dir.close();

    allocator.free(view.current_date_string);
    allocator.free(view.full_current_date_string);
    allocator.free(view.full_current_secondary_date_string);
    for (view.events_for_month) |element| allocator.free(element);
    allocator.free(view.events_for_month);

    allocator.free(settings.language.?);
    allocator.free(settings.disabled_event_categories);

    http_client.deinit();

    // _ = gpallocator.detectLeaks();
    // _ = gpallocator.deinit();
}
pub fn refreshTranslationOptions() !void {
    if (installed_translation_options != null) {
        for (installed_translation_options.?) |element| allocator.free(element);
        allocator.free(installed_translation_options.?);
    }
    if (not_installed_translation_options != null) {
        for (not_installed_translation_options.?) |element| allocator.free(element);
        allocator.free(not_installed_translation_options.?);
    }

    var translations_dir = try env_dir.openDir("translations", .{ .iterate = true });
    defer translations_dir.close();
    var translations_iterator = translations_dir.iterateAssumeFirstIteration();
    var translation_options_list = std.ArrayList([]const u8).init(allocator);
    while (try translations_iterator.next()) |file| {
        try memcpyAppend(file.name, &translation_options_list);
    }
    installed_translation_options = try translation_options_list.toOwnedSlice();

    const uri = comptime try std.Uri.parse("https://api.github.com/repos/Epigeos-com/Reo/contents/translations");
    const response = try sendHttpRequest(allocator, uri, 4096);
    defer allocator.free(response);
    const json: std.json.Parsed(std.json.Value) = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    var not_installed_translation_options_list = std.ArrayList([]const u8).init(allocator);
    for (json.value.array.items) |item| {
        const name = item.object.get("name").?.string;
        if (translations_dir.statFile(name) catch null) |stat| {
            if (stat.size != item.object.get("size").?.integer) try downloadTranslation(name);
        } else {
            try memcpyAppend(name, &not_installed_translation_options_list);
        }
    }
    not_installed_translation_options = try not_installed_translation_options_list.toOwnedSlice();
    json.deinit();
}
pub fn downloadTranslation(lang: []const u8) !void {
    const url = try std.fmt.allocPrint(allocator, "https://raw.githubusercontent.com/Epigeos-com/Reo/master/translations/{s}", .{lang});
    std.debug.print("downloadTranslation: {s}, {s}\n", .{ lang, url });
    defer allocator.free(url);
    const uri = try std.Uri.parse(url);
    const response = try sendHttpRequest(allocator, uri, 2048);
    defer allocator.free(response);
    std.debug.print("downloadTranslation: {s}; {s}\n", .{ lang, response });
}
pub fn loadTranslation() !void {
    if (dictionary_english != null) {
        for (dictionary_english.?) |element| allocator.free(element);
        for (dictionary_translated.?) |element| allocator.free(element);
        allocator.free(dictionary_english.?);
        allocator.free(dictionary_translated.?);
        dictionary_english = null;
        dictionary_translated = null;
    }

    if (settings.language == null) return;

    const path = try std.fmt.allocPrint(allocator, "translations/{s}", .{settings.language.?});
    const file = try env_dir.readFileAlloc(allocator, path, 16000);
    var lines = std.mem.splitSequence(u8, file, "\n");
    var english_list = std.ArrayList([]const u8).init(allocator);
    var translated_list = std.ArrayList([]const u8).init(allocator);
    var is_next_line_english = true;
    while (lines.next()) |line| {
        try memcpyAppend(line, &if (is_next_line_english) english_list else translated_list);
        is_next_line_english = !is_next_line_english;
    }
    dictionary_english = try english_list.toOwnedSlice();
    dictionary_translated = try translated_list.toOwnedSlice();
    allocator.free(file);
    allocator.free(path);
}
pub fn translate(text: []const u8) []const u8 {
    if (dictionary_english == null) return text;
    const index = indexOfStringArray(dictionary_english.?, text);
    if (index == null) return text;
    return dictionary_translated.?[index.?];
}
pub fn translateToEnglish(text: []const u8) []const u8 {
    if (dictionary_english == null) return text;
    const index = indexOfStringArray(dictionary_translated.?, text);
    if (index == null) return text;
    return dictionary_english.?[index.?];
}

pub fn indexOfStringArray(haystack: []const []const u8, needle: []const u8) ?usize {
    for (haystack, 0..) |element, i| {
        if (std.mem.eql(u8, element, needle)) {
            return i;
        }
    }
    return null;
}
pub fn appendFile(dir: std.fs.Dir, sub_path: []const u8, data: []const u8) !void {
    const file = try dir.openFile(sub_path, .{ .mode = .write_only });
    defer file.close();
    try file.seekFromEnd(0);
    var writer = file.writer();
    try writer.writeAll(data);
}
pub fn memcpyAppend(array: anytype, list_of_arrays: *std.ArrayList(@TypeOf(array))) !void {
    const alloc = try list_of_arrays.allocator.alloc(@TypeOf(array[0]), array.len);
    @memcpy(alloc, array);
    try list_of_arrays.append(alloc);
}
pub fn sendHttpRequest(allocator_: std.mem.Allocator, uri: std.Uri, comptime header_buffer_size: usize) ![]u8 {
    var header_buffer: [header_buffer_size]u8 = undefined;
    var req = try http_client.open(.GET, uri, .{ .server_header_buffer = &header_buffer });
    defer req.deinit();
    try req.send();
    try req.finish();
    try req.wait();
    if (req.response.status == .ok) {
        const response_buffer: []u8 = try allocator_.alloc(u8, req.response.content_length orelse 0);
        _ = try req.readAll(response_buffer);
        return response_buffer;
    } else {
        return error.ResponseStatusNot200;
    }
}
