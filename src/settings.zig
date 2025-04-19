const std = @import("std");
const manager = @import("manager.zig");
const dates = @import("dates.zig");

// General
pub var primary_calendar: dates.CalendarType = .Attic;
pub var secondary_calendar: dates.CalendarType = .Gregorian;
pub var anniversary_calendar: bool = true; // True - primary, false - secondary

pub var use_low_precision_for_nutation_epsilon0: bool = false;
pub var use_low_precision_for_sun_transit: bool = true;

pub var longitude: f64 = 37.976234;
pub var latitude: f64 = 23.721661;

// Events
pub var disabled_event_categories: []const []const u8 = &.{};
pub var presave_complex_events_for_days: f64 = 30 * 12 * 2; // This many days from today backwards and forwards // These are referance dates from which the events will be ran, e.g. next/moon:0 ran from jd will result in a date later than jd, given that events can be arbitrarily complex, this can be arbitrarily later or earlier, therefore not all events in this range will actually show up and some may show up outside this range

// Gregorian
pub var use_12_hour_format_in_gregorian = false;
pub var use_month_day_format_in_gregorian = false;

// Attic
pub var month_to_double_in_attic: i8 = 6;
pub var romanise_month_names_in_attic = false;

// Display
pub var target_lang: []const u8 = "eng";
pub var light_mode = false;
pub var show_secondary_date_in_month_view = true;
pub var show_secondary_date_in_day_view = true;
pub var automatically_get_sun_position_in_day_view = false;

pub fn saveSettings() !void {
    const disabled_event_categories_string = try std.mem.join(manager.allocator, ";", disabled_event_categories);
    const settings_string = try std.fmt.allocPrint(manager.allocator, "{d}\n{d}\n{}\n{}\n{}\n{d}\n{d}\n{}\n{}\n{d}\n{}\n{s}\n{d}\n{s}\n{}\n{}\n{}\n{}", .{ @intFromEnum(primary_calendar), @intFromEnum(secondary_calendar), anniversary_calendar, use_low_precision_for_nutation_epsilon0, use_low_precision_for_sun_transit, longitude, latitude, use_12_hour_format_in_gregorian, use_month_day_format_in_gregorian, month_to_double_in_attic, romanise_month_names_in_attic, disabled_event_categories_string, presave_complex_events_for_days, target_lang, light_mode, show_secondary_date_in_month_view, show_secondary_date_in_day_view, automatically_get_sun_position_in_day_view });
    try manager.env_dir.writeFile(.{ .sub_path = "settings.data", .data = settings_string });
    manager.allocator.free(disabled_event_categories_string);
    manager.allocator.free(settings_string);
}
pub fn loadSettings() !void {
    const file = manager.env_dir.readFileAlloc(manager.allocator, "settings.data", 10000) catch return;
    var lines = std.mem.splitSequence(u8, file, "\n");

    primary_calendar = @enumFromInt(try std.fmt.parseInt(u8, lines.next().?, 10));
    secondary_calendar = @enumFromInt(try std.fmt.parseInt(u8, lines.next().?, 10));

    manager.allocator.free(file);
}
