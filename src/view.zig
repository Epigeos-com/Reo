const std = @import("std");
const sdl = @import("sdl.zig");
const manager = @import("manager.zig");
const settings = @import("settings.zig");
const dates = @import("dates.zig");
const events = @import("events.zig");

// Frontend vars
pub var full_current_date_string: []u8 = undefined;
pub var current_date_string: []u8 = undefined;
//

pub var current_jd: f64 = -1;
pub var current_date_info: dates.DateInfo = undefined;
pub var is_day_view = false;

pub fn refreshCurrentDateInfo() void {
    current_date_info = dates.getDateInfo(settings.primary_calendar, current_jd, false, false) catch undefined;
    manager.allocator.free(full_current_date_string);
    manager.allocator.free(current_date_string);
    full_current_date_string = if (is_day_view) std.fmt.allocPrint(manager.allocator, "{d}", .{current_date_info.main_date}) catch undefined else std.fmt.allocPrint(manager.allocator, "{m}", .{current_date_info.main_date}) catch undefined;

    if (settings.primary_calendar == .Attic) {
        const month_names = if (settings.romanise_month_names_in_attic) [_][]const u8{ "Hekatombaion", "Metageitnion", "Boedromion", "Pyanepsion", "Maimakterion", "Poseideon", "Gamelion", "Anthesterion", "Elaphebolion", "Mounichion", "Thargelion", "Skirophorion" } else [_][]const u8{ "Ἑκατομβαιών", "Μεταγειτνιών", "Βοηδρομιών", "Πυανεψιών", "Μαιμακτηριών", "Ποσειδεών", "Γαμηλιών", "Ἀνθεστηριών", "Ἐλαφηβολιών", "Μουνυχιών", "Θαργηλιών", "Σκιροφοριών" };
        const month_name = if (current_date_info.months_in_year == 13)
            if (current_date_info.main_date.month == settings.month_to_double_in_attic + 1)
                std.fmt.allocPrint(manager.allocator, "{s} Β", .{month_names[@as(u8, @intCast(settings.month_to_double_in_attic)) - 1]}) catch "AllocPrintError"
            else
                std.fmt.allocPrint(manager.allocator, "{s}", .{if (current_date_info.main_date.month <= settings.month_to_double_in_attic) month_names[@as(u8, @intCast(current_date_info.main_date.month)) - 1] else month_names[@as(u8, @intCast(current_date_info.main_date.month)) - 2]}) catch "AllocPrintError"
        else
            std.fmt.allocPrint(manager.allocator, "{s}", .{month_names[@as(u8, @intCast(current_date_info.main_date.month)) - 1]}) catch "AllocPrintError";

        current_date_string = if (is_day_view) std.fmt.allocPrint(manager.allocator, "{d} {s}", .{ std.math.floor(current_date_info.main_date.day), month_name }) catch undefined else std.fmt.allocPrint(manager.allocator, "{s}", .{month_name}) catch undefined;

        manager.allocator.free(month_name);
    } else {
        const month_names = [_][]const u8{ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };
        current_date_string = if (is_day_view) std.fmt.allocPrint(manager.allocator, "{d} {s}", .{ std.math.floor(current_date_info.main_date.day), month_names[@as(u8, @intCast(current_date_info.main_date.month)) - 1] }) catch undefined else std.fmt.allocPrint(manager.allocator, "{s}", .{month_names[@as(u8, @intCast(current_date_info.main_date.month)) - 1]}) catch undefined;
    }

    sdl.updateView();
}
pub fn changeDateByOneUnit(is_forward: bool) void {
    if (is_day_view) {
        current_jd += if (is_forward) 1 else -1;
    } else {
        current_jd = current_date_info.first_of_the_month_jd + if (is_forward) @as(f32, @floatFromInt(current_date_info.days_in_month)) else -1;
    }
    refreshCurrentDateInfo();
}
pub fn toggleDay(date: f64) void {
    if (date != -1) current_jd = date;
    is_day_view = !is_day_view;
    refreshCurrentDateInfo();
}

fn displayError(err: anyerror) void {
    _ = err catch undefined;
    return undefined;
}

// Event
var event_calendar: dates.CalendarType = .Gregorian;
var event_repeat_calendar: dates.CalendarTypeSetting = .anniversary;
var event_date: []const u8 = "";
var event_category: []const u8 = "";
var event_title: []const u8 = "";
var event_background_color: []const u8 = "";
var event_text_color: []const u8 = "";
var event_repeat_until: []const u8 = "";
var event_repeat_is_where: bool = false; // false = every, true = where
var event_repeat_every_days: []const u8 = "";
var event_repeat_every_years: []const u8 = "";
var advanced_event_input: []const u8 = "";
var is_editing_event: bool = false;
var last_edited_event: []const u8 = "";
export fn openEventDialog() void {
    if (is_day_view) {
        event_calendar = settings.primary_calendar;
        event_date = std.fmt.allocPrint(manager.allocator, "{d}", .{current_date_info.main_date}) catch undefined; // TODO: free this
    }
    toggleDialog("eventDialog", "");
}
fn onEventCalendarChange(new_value: dates.CalendarType) !void { // Convert dates from old calendar to new calendar
    event_date = std.fmt.allocPrint(manager.allocator, "{d}", .{dates.jdToDate(new_value, try dates.dateToJD(dates.Date.parse(event_calendar, event_date), true, true), true, true)}) catch |err| displayError(err); // TODO: free this
    event_repeat_until = std.fmt.allocPrint(manager.allocator, "{d}", .{dates.jdToDate(new_value, try dates.dateToJD(dates.Date.parse(event_calendar, event_repeat_until), true, true), true, true)}) catch |err| displayError(err); // TODO: free this
}
fn addEventFromUI() bool {
    if (advanced_event_input.len != 0) { // Complex
        events.addEvent(true, try dates.dateToJD(try dates.Date.parse(event_calendar, event_date), true, true), (if (event_repeat_until.len == 0) ?"-1" else dates.dateToJD(dates.Date.parse(event_calendar, event_repeat_until), true, true)), event_category, event_calendar, event_repeat_calendar, advanced_event_input, event_title, event_background_color, event_text_color);
    } else if (event_repeat_until.len == 0 and event_repeat_every_days.len == 0 and event_repeat_every_years.len == 0) { // Non-repeating
        const jd_start = try dates.dateToJD(try dates.Date.parse(event_calendar, event_date), true, true);
        events.addEvent(false, jd_start, jd_start, event_category, event_calendar, event_calendar, event_title, event_background_color, event_text_color);
    } else { // Simple repeating
        const repeat_formula = ((if (event_repeat_every_days.len == 0) "" else std.fmt.allocPrint(manager.allocator, "&every-day-{s}", .{event_repeat_every_days})) + (if (event_repeat_every_years.len == 0) "" else std.fmt.allocPrint(manager.allocator, "&every-year-{s}", .{event_repeat_every_years})))[1..]; // TODO: Free this
        events.addEvent(false, try dates.dateToJD(try dates.Date.parse(event_calendar, event_date), true, true), (if (event_repeat_until.len == 0) ?"-1" else dates.dateToJD(dates.Date.parse(event_calendar, event_repeat_until), true, true)), event_category, event_calendar, event_repeat_calendar, repeat_formula, event_title, event_background_color, event_text_color);
    }
    closeEventUIFromUI();
}
fn editEventOpenUI(ev: []u8) void {
    var args = std.mem.splitSequence(u8, ev, ";");
    const args0 = args.next().?;
    const args1 = args.next().?;
    const args2 = args.next().?;
    const args3 = args.next().?;
    const args4 = args.next().?;
    const args5 = args.next().?;
    const args6 = args.next().?;
    const args7 = args.next().?;
    const args8 = args.next().?;

    event_calendar = @enumFromInt(std.fmt.parseInt(u8, args3, 10));
    event_date = if (std.mem.eql(u8, args0, "-1")) "" else std.fmt.allocPrint(manager.allocator, "{d}", .{dates.jdToDate(event_calendar, std.fmt.parseFloat(f64, args0), true, true)}); // TODO: Free this
    event_repeat_until = if (std.mem.eql(u8, args1, "-1")) "" else std.fmt.allocPrint(manager.allocator, "{d}", .{dates.jdToDate(event_calendar, std.fmt.parseFloat(f64, args1), true, true)}); // TODO: Free this
    event_category = args2;
    event_title = args6;
    event_background_color = args7;
    event_text_color = args8;
    if (args5.len != 0) {
        event_repeat_calendar = @enumFromInt(std.fmt.parseInt(u8, args4, 10));
        while (std.mem.splitSequence(u8, args5, "&")) |arg| {
            var split = std.mem.splitSequence(u8, arg, "-");
            const split0 = split.next().?;
            const is_where = std.mem.eql(u8, split0, "where");
            if (is_where or std.mem.eql(u8, split0, "every")) {
                if (std.mem.eql(u8, split.next().?, "day")) {
                    event_repeat_every_days = split.next().?;
                } else // year
                {
                    event_repeat_every_years = split.next().?;
                }
                event_repeat_is_where = is_where;
            } else {
                advanced_event_input = args5;
                break;
            }
        }
    } else {
        event_repeat_until = "";
    }
    is_editing_event = true;
    last_edited_event = ev;
}
fn editEventFromUI() bool {
    if (addEventFromUI()) events.removeEvent(last_edited_event) else return false;
    return true;
}
export fn deleteEventFromUI() void {
    toggleDialog("eventDialog", "");
    events.removeEvent(!std.mem.eql(u8, advanced_event_input, ""), last_edited_event) catch |err| displayError(err);
    closeEventUI();
}
export fn closeEventUIFromUI() void {
    toggleDialog("eventDialog", "");
    closeEventUI();
}
fn closeEventUI() void {
    if (is_editing_event) {
        event_date = "";
        event_category = "";
        event_title = "";
        event_background_color = "";
        event_text_color = "";
        event_repeat_until = "";
        event_repeat_is_where = false;
        event_repeat_every_days = "";
        event_repeat_every_years = "";
        advanced_event_input = "";
        is_editing_event = false;
    }
}

// Goto
var goto_calendar: dates.CalendarType = .Gregorian;
var goto_date: []const u8 = "";
export fn goToDateFromUI() void {
    current_jd = dates.dateToJD(dates.Date.parse(goto_calendar, goto_date) catch undefined, true, false) catch dates.now();
    toggleDialog("gotoDialog", "");
    if (std.mem.containsAtLeast(u8, goto_date, 2, "/")) is_day_view = true;
    refreshCurrentDateInfo();
    goto_date = "";
}

// Settings
export fn saveSettingsFromUI(primary_calendar: u8, secondary_calendar: u8, anniversary_calendar: bool, use_low_precision_for_nutation_epsilon0: bool, use_low_precision_for_sun_transit: bool, longitude: f64, latitude: f64, disabled_event_categories: [*]const []const u8, disabled_event_categories_len: usize, presave_complex_events_for_days: f64, use_12_hour_format_in_gregorian: bool, use_month_day_format_in_gregorian: bool, month_to_double_in_attic: i8, romanise_month_names_in_attic: bool, target_lang: [*]const u8, target_lang_len: usize, light_mode: bool, show_secondary_date_in_month_view: bool, show_secondary_date_in_day_view: bool, automatically_get_sun_position_in_day_view: bool) void {
    toggleDialog("settingsDialog", "");

    settings.primary_calendar = @enumFromInt(primary_calendar);
    settings.secondary_calendar = @enumFromInt(secondary_calendar);
    settings.anniversary_calendar = anniversary_calendar;
    settings.use_low_precision_for_nutation_epsilon0 = use_low_precision_for_nutation_epsilon0;
    settings.use_low_precision_for_sun_transit = use_low_precision_for_sun_transit;
    settings.longitude = longitude;
    settings.latitude = latitude;
    settings.disabled_event_categories = disabled_event_categories[0..disabled_event_categories_len];
    settings.presave_complex_events_for_days = presave_complex_events_for_days;
    settings.use_12_hour_format_in_gregorian = use_12_hour_format_in_gregorian;
    settings.use_month_day_format_in_gregorian = use_month_day_format_in_gregorian;
    settings.month_to_double_in_attic = month_to_double_in_attic;
    settings.romanise_month_names_in_attic = romanise_month_names_in_attic;
    settings.target_lang = target_lang[0..target_lang_len];
    settings.light_mode = light_mode;
    settings.show_secondary_date_in_month_view = show_secondary_date_in_month_view;
    settings.show_secondary_date_in_day_view = show_secondary_date_in_day_view;
    settings.automatically_get_sun_position_in_day_view = automatically_get_sun_position_in_day_view;

    refreshCurrentDateInfo();
    settings.saveSettings() catch |err| displayError(err);
}
pub fn loadCurrentSettingsIntoUI() void {
    toggleDialog("settingsDialog", "");

    const disabled_event_categories: [*]const []const u8 = @ptrCast(@constCast(&settings.disabled_event_categories));
    const target_lang: [*]const u8 = @ptrCast(@constCast(&settings.target_lang));
    loadSettingsIntoUI(@intFromEnum(settings.primary_calendar), @intFromEnum(settings.secondary_calendar), settings.anniversary_calendar, settings.use_low_precision_for_nutation_epsilon0, settings.use_low_precision_for_sun_transit, settings.longitude, settings.latitude, disabled_event_categories, settings.presave_complex_events_for_days, settings.use_12_hour_format_in_gregorian, settings.use_month_day_format_in_gregorian, settings.month_to_double_in_attic, settings.romanise_month_names_in_attic, target_lang, settings.light_mode, settings.show_secondary_date_in_month_view, settings.show_secondary_date_in_day_view, settings.automatically_get_sun_position_in_day_view);

    refreshCurrentDateInfo();
    settings.saveSettings() catch |err| displayError(err);
}

fn loadSettingsIntoUI(primaryCalendar: u8, secondaryCalendar: u8, anniversaryCalendar: bool, useLowPrecisionForNutationEpsilon0: bool, useLowPrecisionForSunTransit: bool, longitude: f64, latitude: f64, disabledEventCategories: [*]const []const u8, presaveComplexEventsForDays: f64, use12HourFormatInGregorian: bool, useMonthDayFormatInGregorian: bool, monthToDoubleInAttic: i8, romaniseMonthNamesInAttic: bool, targetLang: [*]const u8, lightMode: bool, showSecondaryDateInMonthView: bool, showSecondaryDateInDayView: bool, automaticallyGetSunPositionInDayView: bool) void {
    _ = primaryCalendar;
    _ = secondaryCalendar;
    _ = anniversaryCalendar;
    _ = useLowPrecisionForNutationEpsilon0;
    _ = useLowPrecisionForSunTransit;
    _ = longitude;
    _ = latitude;
    _ = disabledEventCategories;
    _ = presaveComplexEventsForDays;
    _ = use12HourFormatInGregorian;
    _ = useMonthDayFormatInGregorian;
    _ = monthToDoubleInAttic;
    _ = romaniseMonthNamesInAttic;
    _ = targetLang;
    _ = lightMode;
    _ = showSecondaryDateInMonthView;
    _ = showSecondaryDateInDayView;
    _ = automaticallyGetSunPositionInDayView;
}

// Extern old
fn toggleDialog(id: [*]const u8, scrollTo: [*]const u8) void {
    _ = id;
    _ = scrollTo;
}
fn loadEventIntoUI() void {}
