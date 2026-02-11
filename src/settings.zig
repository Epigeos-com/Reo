const std = @import("std");
const manager = @import("manager.zig");
const view = @import("view.zig");
const dates = @import("dates.zig");

// Info
pub const version: []const u8 = "16.7.O701Y1";

// General
pub var primary_calendar: dates.CalendarType = .Attic;
pub var secondary_calendar: dates.CalendarType = .Gregorian;
pub var anniversary_calendar: bool = true; // True - primary, false - secondary

// pub var latitude: f64 = 37.976234;
// pub var longitude: f64 = 23.721661;
pub var latitude: f64 = 51.9382834;
pub var longitude: f64 = 15.5048981;

pub var utc_offset: f64 = 0; // TODO: Get this from system instead of setting it manually? // TODO: Should this do anything besides time display stuff

// Display
pub var language: ?[]u8 = null;
pub var light_mode = false;
pub var show_secondary_date_in_day_view = true;
pub var show_secondary_date_in_month_view = true;
pub var show_secondary_date_for_days_in_month_view = true;

// Events
pub var disabled_event_categories: []const []const u8 = &.{};
pub var presave_complex_events_for_days: f64 = 30 * 12 * 100; // This many days from today backwards and forwards // These are referance dates from which the events will be ran, e.g. next/moon:0 ran from jd will result in a date later than jd, given that events can be arbitrarily complex, this can be arbitrarily later or earlier, therefore not all events in this range will actually show up and some may show up outside this range

// Gregorian
pub var use_12_hour_format_in_gregorian = false;
pub var use_month_day_format_in_gregorian = false;

// Attic
pub var month_to_double_in_attic: i8 = 6;
pub var romanise_month_names_in_attic = false;

pub fn saveSettings() !void {
    const disabled_event_categories_string = try std.mem.join(manager.allocator, ";", disabled_event_categories);
    const settings_string = try std.fmt.allocPrint(manager.allocator, "primary_calendar\n{s}\nsecondary_calendar\n{s}\nanniversary_calendar\n{}\nlatitude\n{d}\nlongitude\n{d}\nutc_offset\n{d}\nlanguage\n{s}\nlight_mode\n{}\nshow_secondary_date_in_day_view\n{}\nshow_secondary_date_in_month_view\n{}\nshow_secondary_date_for_days_in_month_view\n{}\ndisabled_event_categories\n{s}\npresave_complex_events_for_days\n{d}\nuse_12_hour_format_in_gregorian\n{}\nuse_month_day_format_in_gregorian\n{}\nmonth_to_double_in_attic\n{d}\nromanise_month_names_in_attic\n{}", .{ @tagName(primary_calendar), @tagName(secondary_calendar), anniversary_calendar, latitude, longitude, utc_offset, language orelse "", light_mode, show_secondary_date_in_month_view, show_secondary_date_in_day_view, show_secondary_date_for_days_in_month_view, disabled_event_categories_string, presave_complex_events_for_days, use_12_hour_format_in_gregorian, use_month_day_format_in_gregorian, month_to_double_in_attic, romanise_month_names_in_attic });
    try manager.env_dir.writeFile(.{ .sub_path = "reo.cnf", .data = settings_string });
    manager.allocator.free(disabled_event_categories_string);
    manager.allocator.free(settings_string);
}
pub fn loadSettings() !void {
    const file = try manager.env_dir.readFileAlloc(manager.allocator, "reo.cnf", 16000);
    var lines = std.mem.splitSequence(u8, file, "\n");

    var last_setting_name: []const u8 = "";
    var is_next_line_name = true;
    while (lines.next()) |line| {
        if (is_next_line_name) {
            last_setting_name = line;
        } else {
            if (std.mem.eql(u8, last_setting_name, "primary_calendar")) {
                primary_calendar = std.meta.stringToEnum(dates.CalendarType, line) orelse primary_calendar;
            } else if (std.mem.eql(u8, last_setting_name, "secondary_calendar")) {
                secondary_calendar = std.meta.stringToEnum(dates.CalendarType, line) orelse secondary_calendar;
            } else if (std.mem.eql(u8, last_setting_name, "anniversary_calendar")) {
                anniversary_calendar = if (std.mem.eql(u8, line, "true")) true else if (std.mem.eql(u8, line, "false")) false else anniversary_calendar;
            } else if (std.mem.eql(u8, last_setting_name, "latitude")) {
                latitude = std.fmt.parseFloat(f64, line) catch latitude;
            } else if (std.mem.eql(u8, last_setting_name, "longitude")) {
                longitude = std.fmt.parseFloat(f64, line) catch longitude;
            } else if (std.mem.eql(u8, last_setting_name, "utc_offset")) {
                utc_offset = std.fmt.parseFloat(f64, line) catch utc_offset;
            } else if (std.mem.eql(u8, last_setting_name, "language")) {
                if (line.len != 0 and manager.indexOfStringArray(manager.installed_translation_options.?, line) != null) {
                    language = try manager.allocator.alloc(u8, line.len);
                    @memcpy(language.?, line);
                }
            } else if (std.mem.eql(u8, last_setting_name, "light_mode")) {
                light_mode = if (std.mem.eql(u8, line, "true")) true else if (std.mem.eql(u8, line, "false")) false else light_mode;
            } else if (std.mem.eql(u8, last_setting_name, "show_secondary_date_in_day_view")) {
                show_secondary_date_in_day_view = if (std.mem.eql(u8, line, "true")) true else if (std.mem.eql(u8, line, "false")) false else show_secondary_date_in_day_view;
            } else if (std.mem.eql(u8, last_setting_name, "show_secondary_date_in_month_view")) {
                show_secondary_date_in_month_view = if (std.mem.eql(u8, line, "true")) true else if (std.mem.eql(u8, line, "false")) false else show_secondary_date_in_month_view;
            } else if (std.mem.eql(u8, last_setting_name, "show_secondary_date_for_days_in_month_view")) {
                show_secondary_date_for_days_in_month_view = if (std.mem.eql(u8, line, "true")) true else if (std.mem.eql(u8, line, "false")) false else show_secondary_date_for_days_in_month_view;
            } else if (std.mem.eql(u8, last_setting_name, "disabled_event_categories")) {
                var split = std.mem.splitSequence(u8, line, ";");
                var list = std.ArrayList([]const u8).init(manager.allocator);
                while (split.next()) |category| {
                    try list.append(category);
                }
                disabled_event_categories = try list.toOwnedSlice();
            } else if (std.mem.eql(u8, last_setting_name, "presave_complex_events_for_days")) {
                presave_complex_events_for_days = std.fmt.parseFloat(f64, line) catch presave_complex_events_for_days;
            } else if (std.mem.eql(u8, last_setting_name, "use_12_hour_format_in_gregorian")) {
                use_12_hour_format_in_gregorian = if (std.mem.eql(u8, line, "true")) true else if (std.mem.eql(u8, line, "false")) false else use_12_hour_format_in_gregorian;
            } else if (std.mem.eql(u8, last_setting_name, "use_month_day_format_in_gregorian")) {
                use_month_day_format_in_gregorian = if (std.mem.eql(u8, line, "true")) true else if (std.mem.eql(u8, line, "false")) false else use_month_day_format_in_gregorian;
            } else if (std.mem.eql(u8, last_setting_name, "month_to_double_in_attic")) {
                month_to_double_in_attic = std.fmt.parseInt(i8, line, 10) catch month_to_double_in_attic;
            } else if (std.mem.eql(u8, last_setting_name, "romanise_month_names_in_attic")) {
                romanise_month_names_in_attic = if (std.mem.eql(u8, line, "true")) true else if (std.mem.eql(u8, line, "false")) false else romanise_month_names_in_attic;
            }
        }
        is_next_line_name = !is_next_line_name;
    }

    manager.allocator.free(file);
    try updateSettings();
}
pub fn updateSettings() !void {
    try manager.loadTranslation();
    view.updateLightMode();
    view.refreshCurrentDateInfo();
}
