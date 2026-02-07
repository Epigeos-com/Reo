// This file is meant as a connector between frontend and backend, this should be the only file importing sdl.zig

const std = @import("std");
const sdl = @import("sdl.zig");
const manager = @import("manager.zig");
const settings = @import("settings.zig");
const dates = @import("dates.zig");
const events = @import("events.zig");

// Frontend vars
pub var current_date_string: []u8 = &.{};
pub var full_current_date_string: []u8 = &.{};
pub var full_current_secondary_date_string: []u8 = &.{};

//
pub var current_jd: f64 = -1;
pub var current_date_info: dates.DateInfo = undefined;
pub var events_for_month: []const []const []const u8 = &.{};
pub var is_day_view = false;
pub var open_dialog: u8 = 0;

pub fn refreshCurrentDateInfo() void {
    const old_date = current_date_info.main_date;

    current_date_info = dates.getDateInfo(settings.primary_calendar, current_jd, false, false) catch undefined;
    const current_secondary_date = dates.jdToDate(settings.secondary_calendar, if (is_day_view) current_jd else current_date_info.first_of_the_month_jd, false, false) catch undefined;

    if (old_date.month != current_date_info.main_date.month or old_date.year != current_date_info.main_date.year) {
        for (events_for_month) |element| manager.allocator.free(element);
        manager.allocator.free(events_for_month);
        events_for_month = events.getEventsForDatesArray(manager.allocator, current_date_info.first_of_the_month_jd, current_date_info.first_of_the_month_jd + @as(f64, @floatFromInt(current_date_info.days_in_month)) - 1) catch &.{};
    }

    manager.allocator.free(current_date_string);
    manager.allocator.free(full_current_date_string);
    manager.allocator.free(full_current_secondary_date_string);

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
        const month_names = [_][]const u8{ manager.translate("January"), manager.translate("February"), manager.translate("March"), manager.translate("April"), manager.translate("May"), manager.translate("June"), manager.translate("July"), manager.translate("August"), manager.translate("September"), manager.translate("October"), manager.translate("November"), manager.translate("December") };
        current_date_string = if (is_day_view) std.fmt.allocPrint(manager.allocator, "{d} {s}", .{ std.math.floor(current_date_info.main_date.day), month_names[@as(u8, @intCast(current_date_info.main_date.month)) - 1] }) catch undefined else std.fmt.allocPrint(manager.allocator, "{s}", .{month_names[@as(u8, @intCast(current_date_info.main_date.month)) - 1]}) catch undefined;
    }
    full_current_date_string = if (is_day_view) std.fmt.allocPrint(manager.allocator, "{d}", .{current_date_info.main_date}) catch undefined else std.fmt.allocPrint(manager.allocator, "{m}", .{current_date_info.main_date}) catch undefined;
    full_current_secondary_date_string = if (is_day_view) std.fmt.allocPrint(manager.allocator, "{d}", .{current_secondary_date}) catch undefined else std.fmt.allocPrint(manager.allocator, "{m}", .{current_secondary_date}) catch undefined;

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

pub fn updateLightMode() void {
    sdl.updateLightMode();
}
pub fn getPrefPath() []u8 {
    return sdl.getPrefPath();
}

pub const dialog_go_to = 1;
pub const dialog_settings_general = 2;
pub const dialog_settings_display = 3;
pub const dialog_settings_events = 4;
pub const dialog_settings_gregorian = 5;
pub const dialog_settings_attic = 6;
pub fn toggleDialog(dialog: u8) void {
    open_dialog = if (open_dialog == dialog) 0 else dialog;
    sdl.updateView();
}
