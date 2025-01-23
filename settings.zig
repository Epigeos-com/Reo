const dates = @import("dates.zig");
const std = @import("std");
const lang = @import("lang.zig");

// General
pub var primaryCalendar: dates.CalendarType = .Attic;
pub var secondaryCalendar: dates.CalendarType = .Gregorian;

pub var anniversaryCalendar: bool = true; // True - primary, false - secondary
pub var anniversaryCalendarConfirmed: bool = true; // Set to lightMode when settings are saved or loaded to prevent icons from changing modes before settings are closed

pub var useLowPrecisionForNutationEpsilon0: bool = false;
pub var useLowPrecisionForSunTransit: bool = true;

pub var longitude: f64 = 37.976234;
pub var latitude: f64 = 23.721661;

// Gregorian
pub var use12HourFormatInGregorian = false;
pub var useMonthDayFormatInGregorian = false;

// Attic
pub var monthToDoubleInAttic: i8 = 6;
pub var doubledMonthNameFormattingInAttic: []u8 = "{originalName} II";
pub var romaniseMonthNamesInAttic = false;

// Events
pub var disabledEventCategories: []const []const u8 = &.{};
pub var presaveComplexEventsForDays: f64 = 30 * 12 * 2; // This many days from today backwards and forwards // These are referance dates from which the events will be ran, e.g. next/moon:0 ran from JD will result in a date later than JD, given that events can be arbitrarily complex, this can be arbitrarily later or earlier, therefore not all events in this range will actually show up and some may show up outside this range

// Memory vars and fns - not settings
pub var envPath: []u8 = undefined;
pub var envDir: std.fs.Dir = undefined;

pub var gpallocator = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpallocator.allocator();

pub fn initApp() !void {
    envPath = std.fs.getAppDataDir(allocator, "Epigeos/hydor/Reo") catch try std.fmt.allocPrint(allocator, "data", .{});

    // Ensure all paths are there
    envDir = try std.fs.cwd().makeOpenPath(envPath, .{});
    const readme = try envDir.createFile("readBeforeEditingOrDeletingAnything.txt", .{ .truncate = false });
    if (try readme.getEndPos() == 0) {
        try readme.writeAll("General:\n  All files in here are regenerated if this file is detected missing, they're not emptied to avoid accidents\nFor events:\n  The first and last line of a file shall always be empty and all repeat formulae shall be all lowercase\n  Use // at the beginning of a line for comments");
        const events = try envDir.createFile("events.data", .{ .truncate = false });
        try events.writeAll("\n");
        events.close();
        const complexEvents = try envDir.createFile("complexEvents.data", .{ .truncate = false });
        try complexEvents.writeAll("\n");
        complexEvents.close();
        envDir.makeDir("translations") catch undefined;
    }
    readme.close();

    try lang.loadTranslations("eng");
}
pub fn deinitApp() void {
    allocator.free(envPath);
    envDir.close();
    lang.unloadTranslations();

    // _ = gpallocator.detectLeaks(); // TODO: fix the leaks from presaveComplexEvents()
    // _ = gpallocator.deinit();
}
pub fn appendFile(dir: std.fs.Dir, sub_path: []const u8, data: []const u8) !void {
    const file = try dir.openFile(sub_path, .{ .mode = .write_only });
    defer file.close();
    try file.seekFromEnd(0);
    var writer = file.writer();
    try writer.writeAll(data);
}
