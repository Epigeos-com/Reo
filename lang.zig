const std = @import("std");
const settings = @import("settings.zig");

// monthNames = []u8 { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }

// List<string> monthNames = Settings.romaniseMonthNamesInAttic ? (new List<string>() { "Hekatombaion", "Metageitnion", "Boedromion", "Pyanepsion", "Maimakterion", "Poseideon", "Gamelion", "Anthesterion", "Elaphebolion", "Mounichion", "Thargelion", "Skirophorion" }) : (new List<string>() { "Ἑκατομβαιών", "Μεταγειτνιών", "Βοηδρομιών", "Πυανεψιών", "Μαιμακτηριών", "Ποσειδεών", "Γαμηλιών", "Ἀνθεστηριών", "Ἐλαφηβολιών", "Μουνυχιών", "Θαργηλιών", "Σκιροφοριών" });
//     if (monthsInYear == 13) monthNames.Insert(Settings.monthToDoubleInAttic, Settings.doubledMonthNameFormattingInAttic.Replace("{originalName}", monthNames[Settings.monthToDoubleInAttic - 1]));

var targetLang: []const u8 = "eng";
var translationFile: []u8 = undefined;
var map: std.StringHashMap([]const u8) = undefined;

pub fn loadTranslations(lang: []const u8) !void {
    targetLang = lang;
    if (std.mem.eql(u8, targetLang, "eng")) return;
    map = std.StringHashMap([]const u8).init(settings.allocator);

    const path = try std.mem.join(settings.allocator, "", &[3][]const u8{ "translations/", targetLang, ".epilang" });
    defer settings.allocator.free(path);
    translationFile = try settings.envDir.readFileAlloc(settings.allocator, path, 100000000);

    var lines = std.mem.splitSequence(u8, translationFile, "\n");
    while (lines.next()) |line| {
        var split = std.mem.splitSequence(u8, line, "#");
        if (line.len > 0 and line[0] != '#') {
            try map.put(split.next().?, split.next().?);
        }
    }
}
pub fn unloadTranslations() void {
    settings.allocator.free(translationFile);
    map.deinit();
}

pub fn t(str: []const u8) []const u8 {
    if (std.mem.eql(u8, targetLang, "eng")) {
        return str;
    } else {
        return map.get(str) orelse str;
    }
}
// Needs to be manually freed
pub fn ta(allocator: std.mem.Allocator, array: []const []const u8) ![][]const u8 {
    var newArray = try allocator.alloc([]const u8, array.len);
    if (std.mem.eql(u8, targetLang, "eng")) {
        for (array, 0..) |element, i| {
            newArray[i] = element;
        }
        return newArray;
    } else {
        for (array, 0..) |element, i| {
            newArray[i] = map.get(element) orelse element;
        }
        return newArray;
    }
}

pub fn downloadTranslationPack(lang: []const u8) !void {
    var client = std.http.Client{ .allocator = settings.allocator };
    defer client.deinit();

    const uriPath = try std.mem.join(settings.allocator, "", &[3][]const u8{ "https://raw.githubusercontent.com/Epigeos-com/Reo/master/translations/", lang, ".epilang" });
    defer settings.allocator.free(uriPath);
    const uri = try std.Uri.parse(uriPath);
    var headerBuffer: [1024]u8 = undefined;
    var req = try client.open(.GET, uri, .{ .server_header_buffer = &headerBuffer });
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    if (req.response.status != .ok) return error.CannotRequestFile;
    const content = try req.reader().readAllAlloc(settings.allocator, 100000000);
    defer settings.allocator.free(content);

    const path = try std.mem.join(settings.allocator, "", &[3][]const u8{ "translations/", lang, ".epilang" });
    defer settings.allocator.free(path);
    const file = try settings.envDir.createFile(path, .{});
    try file.writeAll(content);
}
