// This should be the only file importing sdl

const std = @import("std");
pub const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});
const builtin = @import("builtin");

const view = @import("view.zig");
const manager = @import("manager.zig");
const tl = manager.translate;
const settings = @import("settings.zig");
const dates = @import("dates.zig");
const astronomy = @import("astronomy.zig");
const events = @import("events.zig");

const file_icon_bmp = @embedFile("assets/icon.bmp");
const file_baloo2_regular = @embedFile("assets/Baloo2-Regular.ttf");
const file_baloo2_semibold = @embedFile("assets/Baloo2-SemiBold.ttf");
const file_cantarell_regular = @embedFile("assets/Cantarell-Regular.otf");
const file_piazzolla_light = @embedFile("assets/Piazzolla-Light.otf");
const file_piazzolla_sc_thin = @embedFile("assets/PiazzollaSC-Thin.otf");

var window: ?*sdl.SDL_Window = undefined;
var ren: ?*sdl.SDL_Renderer = undefined;
var text_engine: ?*sdl.TTF_TextEngine = undefined;
var width: f32 = undefined;
var height: f32 = undefined;
var android_safe_area_rect: sdl.SDL_Rect = undefined;
var reference_font_size: f32 = undefined;
var font_baloo2: ?*sdl.TTF_Font = undefined;
var font_baloo2_semibold: ?*sdl.TTF_Font = undefined;
var font_cantarell: ?*sdl.TTF_Font = undefined;
var font_piazzolla: ?*sdl.TTF_Font = undefined;
var font_piazzolla_sc: ?*sdl.TTF_Font = undefined;

const ButtonStruct = struct { rect: sdl.SDL_FRect, function_id: u8, arg: struct { toggleDay_date: ?f64 = null, text_input_font_size: ?f32 = null, text_input_id: ?[]const u8 = null, toggleDialog_id: ?u8 = null, dropdown_input_options: ?[]const []const u8 = null, dropdown_option_value: ?[]const u8 = null, bool_input_value: ?*bool = null } = undefined };
var buttons = std.ArrayList(ButtonStruct).init(manager.allocator);
fn isMouseWithinRect(mouse_x: f32, mouse_y: f32, rect: sdl.SDL_FRect) bool {
    return !((mouse_x < rect.x) or (mouse_x > rect.x + rect.w) or (mouse_y < rect.y) or (mouse_y > rect.y + rect.h));
}
var android_swipe_start_x: f32 = undefined;
var current_text_input: ?ButtonStruct = null;
var current_text_input_value = std.ArrayList(u8).init(manager.allocator);

pub fn main() void {
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO) or !sdl.TTF_Init()) {
        sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, sdl.SDL_GetError());
    }

    const flags: sdl.SDL_WindowFlags = sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_OPENGL;
    window = sdl.SDL_CreateWindow("Reo", 1024, 576, flags);
    if (window == null) sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, sdl.SDL_GetError());
    _ = sdl.SDL_SetWindowIcon(window, sdl.SDL_LoadBMP_IO(sdl.SDL_IOFromConstMem(file_icon_bmp, file_icon_bmp.len), true));

    ren = sdl.SDL_CreateRenderer(window, null);
    if (ren == null) sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, sdl.SDL_GetError());

    text_engine = sdl.TTF_CreateRendererTextEngine(ren);
    if (text_engine == null) sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, sdl.SDL_GetError());

    var width_int: c_int = undefined;
    var height_int: c_int = undefined;
    if (!sdl.SDL_GetWindowSizeInPixels(window, &width_int, &height_int)) sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, sdl.SDL_GetError());
    width = @floatFromInt(width_int);
    height = @floatFromInt(height_int);
    if (builtin.abi.isAndroid()) {
        if (!sdl.SDL_GetWindowSafeArea(window, &android_safe_area_rect)) sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, sdl.SDL_GetError());
        height = @floatFromInt(android_safe_area_rect.h);
    }
    reference_font_size = 50 * std.math.pow(f32, @sqrt(width * width + height * height), 0.8) / 1000;

    font_baloo2 = sdl.TTF_OpenFontIO(sdl.SDL_IOFromConstMem(@constCast(file_baloo2_regular), file_baloo2_regular.len), true, 64);
    if (font_baloo2 == null) sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, sdl.SDL_GetError());
    font_baloo2_semibold = sdl.TTF_OpenFontIO(sdl.SDL_IOFromConstMem(@constCast(file_baloo2_semibold), file_baloo2_semibold.len), true, 64);
    if (font_baloo2_semibold == null) sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, sdl.SDL_GetError());
    font_cantarell = sdl.TTF_OpenFontIO(sdl.SDL_IOFromConstMem(@constCast(file_cantarell_regular), file_cantarell_regular.len), true, 64);
    if (font_cantarell == null) sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, sdl.SDL_GetError());
    font_piazzolla = sdl.TTF_OpenFontIO(sdl.SDL_IOFromConstMem(@constCast(file_piazzolla_light), file_piazzolla_light.len), true, 64);
    if (font_piazzolla == null) sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, sdl.SDL_GetError());
    font_piazzolla_sc = sdl.TTF_OpenFontIO(sdl.SDL_IOFromConstMem(@constCast(file_piazzolla_sc_thin), file_piazzolla_sc_thin.len), true, 64);
    if (font_piazzolla_sc == null) sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, sdl.SDL_GetError());

    manager.initApp() catch sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, "Failed to manager.initApp().");
    defer manager.deinitApp();

    var event: sdl.SDL_Event = undefined;
    _ = sdl.SDL_SetHint(sdl.SDL_HINT_ANDROID_TRAP_BACK_BUTTON, "1");
    var quit = false;
    while (!quit) {
        while (sdl.SDL_PollEvent(@constCast(&event))) {
            if (event.type == sdl.SDL_EVENT_QUIT) {
                quit = true;
            } else if (event.type == sdl.SDL_EVENT_WINDOW_RESTORED and builtin.abi.isAndroid()) {
                updateView();
            } else if (event.type == sdl.SDL_EVENT_WINDOW_RESIZED) {
                if (!sdl.SDL_GetWindowSizeInPixels(window, &width_int, &height_int)) sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, sdl.SDL_GetError());
                width = @floatFromInt(width_int);
                if (!builtin.abi.isAndroid()) height = @floatFromInt(height_int);
                reference_font_size = 50 * std.math.pow(f32, @sqrt(width * width + height * height), 0.8) / 1000;
                updateView();
            } else if (builtin.abi.isAndroid() and event.type == sdl.SDL_EVENT_MOUSE_BUTTON_DOWN) {
                android_swipe_start_x = event.button.x;
            } else if (builtin.abi.isAndroid() and event.type == sdl.SDL_EVENT_MOUSE_BUTTON_UP and @abs(event.button.x - android_swipe_start_x) > width / 20) {
                if (view.open_dialog == 0) view.changeDateByOneUnit(event.button.x < android_swipe_start_x);
                android_swipe_start_x = undefined;
            } else if (event.type == sdl.SDL_EVENT_MOUSE_BUTTON_UP) {
                var was_a_button_triggered = false;
                if (current_text_input != null and current_text_input.?.arg.dropdown_input_options == null) confirmTextInput(); // Text input is active, but it's not a dropdown
                for (buttons.items) |button| {
                    if (isMouseWithinRect(event.button.x, event.button.y, button.rect)) {
                        switch (button.function_id) {
                            0 => view.toggleDay(button.arg.toggleDay_date.?),
                            1 => view.changeDateByOneUnit(false),
                            2 => view.changeDateByOneUnit(true),
                            3 => startTextInput(button),
                            4 => view.toggleDialog(button.arg.toggleDialog_id.?),
                            5 => {
                                current_text_input_value.clearAndFree();
                                current_text_input_value.appendSlice(button.arg.dropdown_option_value.?) catch std.debug.panic("OOM", .{});
                                confirmTextInput();
                            },
                            6 => {
                                button.arg.bool_input_value.?.* = !button.arg.bool_input_value.?.*;
                                settings.saveSettings() catch |err| std.debug.panic("Error saving settings: {}", .{err});
                                settings.updateSettings() catch |err| std.debug.panic("Error updating settings: {}", .{err});
                            },
                            else => std.debug.panic("Invalid button function id: {d}", .{button.function_id}),
                        }
                        was_a_button_triggered = true;
                        break;
                    }
                }
                if (current_text_input != null and current_text_input.?.arg.dropdown_input_options != null and !was_a_button_triggered) confirmTextInput(); // Dropdown is active and no button was triggered (no option selected)
            } else if (event.type == sdl.SDL_EVENT_KEY_DOWN) {
                if (event.key.key == sdl.SDLK_LEFT) {
                    if (view.open_dialog == 0) view.changeDateByOneUnit(false);
                } else if (event.key.key == sdl.SDLK_RIGHT) {
                    if (view.open_dialog == 0) view.changeDateByOneUnit(true);
                } else if (event.key.key == sdl.SDLK_ESCAPE) {
                    if (view.open_dialog != 0) {
                        view.toggleDialog(view.open_dialog);
                        updateView();
                    } else if (view.is_day_view) {
                        view.toggleDay(-1);
                    }
                } else if (event.key.key == sdl.SDLK_AC_BACK) {
                    if (view.open_dialog != 0) {
                        view.toggleDialog(view.open_dialog);
                        updateView();
                    } else if (view.is_day_view) {
                        view.toggleDay(-1);
                    } else {
                        _ = sdl.SDL_MinimizeWindow(window);
                    }
                } else if (current_text_input != null) {
                    if (event.key.key == sdl.SDLK_RETURN) {
                        confirmTextInput();
                    } else if (event.key.key == sdl.SDLK_BACKSPACE) {
                        _ = current_text_input_value.pop();
                        updateView();
                    } else if (event.key.key == sdl.SDLK_V) {
                        std.debug.print("sdgfsdf: {d}, {d}\n", .{ sdl.SDL_GetModState(), sdl.SDL_KMOD_CTRL });
                        const text = std.mem.span(sdl.SDL_GetClipboardText());
                        current_text_input_value.appendSlice(text) catch std.debug.panic("OOM", .{});
                        updateView();
                    }
                } else if (event.key.key == sdl.SDLK_S) { // TODO: Remove this and add a button for opening settings
                    view.toggleDialog(view.dialog_settings_general);
                }
            } else if (event.type == sdl.SDL_EVENT_TEXT_INPUT) {
                const text = std.mem.span(event.text.text);
                current_text_input_value.appendSlice(text) catch std.debug.panic("OOM", .{});
                updateView();
            }
        }
    }

    buttons.deinit();
    sdl.SDL_DestroyRenderer(ren);
    sdl.SDL_DestroyWindow(window);
    sdl.SDL_Quit();
}

pub fn updateView() void {
    buttons.clearAndFree();
    if (view.is_day_view) renderDayView() else renderMonthView();
    switch (view.open_dialog) {
        view.dialog_go_to => renderGoToDialog(),
        view.dialog_settings_general => renderSettingsDialog(view.dialog_settings_general),
        view.dialog_settings_display => renderSettingsDialog(view.dialog_settings_display),
        view.dialog_settings_events => renderSettingsDialog(view.dialog_settings_events),
        view.dialog_settings_gregorian => renderSettingsDialog(view.dialog_settings_gregorian),
        view.dialog_settings_attic => renderSettingsDialog(view.dialog_settings_attic),
        else => undefined,
    }
    _ = sdl.SDL_RenderPresent(ren);
}
fn renderMonthView() void {
    _ = sdl.SDL_SetRenderDrawColor(ren, color_background[0], color_background[1], color_background[2], color_background[3]);
    _ = sdl.SDL_RenderClear(ren);

    const top_bar_height = renderCalendarTopBar();
    const space_above_grid = top_bar_height;
    const month_grid_height = height - top_bar_height + if (builtin.abi.isAndroid()) @as(f32, @floatFromInt(android_safe_area_rect.y)) else 0;

    const thickness: f32 = 2;
    _ = sdl.SDL_SetRenderScale(ren, thickness, thickness);

    const row_count = @max(view.current_date_info.min_rows, @divFloor(view.current_date_info.days_in_month, view.current_date_info.row_size));
    const h = (month_grid_height - thickness) / @as(f32, @floatFromInt(row_count));
    const w = (width - thickness) / @as(f32, @floatFromInt(view.current_date_info.row_size));
    _ = sdl.SDL_SetRenderDrawColor(ren, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);

    for (0..row_count + 1) |i| {
        const float_i: f32 = @floatFromInt(i);
        _ = sdl.SDL_RenderLine(ren, 0, (float_i * h + space_above_grid) / thickness, width / thickness, (float_i * h + space_above_grid) / thickness);
    }
    for (0..view.current_date_info.row_size + 1) |i| {
        const float_i: f32 = @floatFromInt(i);
        _ = sdl.SDL_RenderLine(ren, float_i * w / thickness, space_above_grid / thickness, float_i * w / thickness, (month_grid_height + space_above_grid) / thickness - 1);
    }

    _ = sdl.SDL_SetRenderScale(ren, 1, 1);

    var today = @floor(dates.now()) + 0.5;
    if (settings.primary_calendar == .Attic and today >= view.current_date_info.first_of_the_month_jd and today - 1 <= view.current_date_info.first_of_the_month_jd + @as(f64, @floatFromInt(view.current_date_info.days_in_month)) - 1) {
        if (dates.now() < today + astronomy.getTimeOfSunTransitRiseSet(today, false, true, false)[1]) today -= 1;
    }
    var secondary_date_info = dates.getDateInfo(settings.secondary_calendar, view.current_date_info.first_of_the_month_jd, false, false) catch undefined;
    var secondary_day_num = @as(u8, @intFromFloat(@floor(secondary_date_info.main_date.day))) - 1;
    for (0..view.current_date_info.days_in_month) |i| {
        const current_day_rect_jd = view.current_date_info.first_of_the_month_jd + @as(f64, @floatFromInt(i));

        var number_string: []u8 = undefined;
        if (settings.show_secondary_date_for_days_in_month_view) {
            secondary_day_num += 1;
            if (secondary_day_num > secondary_date_info.days_in_month) {
                secondary_day_num = 1;
                secondary_date_info = dates.getDateInfo(settings.secondary_calendar, current_day_rect_jd, false, false) catch undefined;
            }
            number_string = std.fmt.allocPrint(manager.allocator, "{d} ({d})", .{ i + 1, secondary_day_num }) catch undefined;
        } else {
            number_string = std.fmt.allocPrint(manager.allocator, "{d}", .{i + 1}) catch undefined;
        }
        _ = sdl.TTF_SetFontSize(font_cantarell, reference_font_size);
        const label = sdl.TTF_CreateText(text_engine, font_cantarell, @ptrCast(number_string.ptr), number_string.len);
        _ = sdl.TTF_SetTextColor(label, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);

        const row_number = @divFloor(i, view.current_date_info.row_size);
        var text_width: c_int = undefined;
        var text_height: c_int = undefined;
        _ = sdl.TTF_GetTextSize(label, &text_width, &text_height);
        const float_i: f32 = @floatFromInt(i);
        const text_x = (float_i - @as(f32, @floatFromInt(row_number * view.current_date_info.row_size)) + 0.5) * w - @as(f32, @floatFromInt(text_width)) / 2;
        const text_y = (@as(f32, @floatFromInt(row_number)) + 0.05) * h + space_above_grid;

        const text_height_float: f32 = @floatFromInt(text_height);
        if (current_day_rect_jd == today) {
            const text_width_float: f32 = @floatFromInt(text_width);
            _ = sdl.SDL_SetRenderDrawColor(ren, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
            _ = sdl.SDL_RenderFillRect(ren, &sdl.SDL_FRect{ .x = text_x, .y = text_y, .w = text_width_float, .h = text_height_float });
            _ = sdl.SDL_RenderFillRect(ren, &sdl.SDL_FRect{ .x = text_x - 1, .y = text_y + 1, .w = text_width_float + 2, .h = text_height_float - 2 });
            _ = sdl.SDL_RenderFillRect(ren, &sdl.SDL_FRect{ .x = text_x - 2, .y = text_y + 2, .w = text_width_float + 4, .h = text_height_float - 4 });
            _ = sdl.TTF_SetTextColor(label, color_background[0], color_background[1], color_background[2], color_background[3]);
        }

        _ = sdl.TTF_DrawRendererText(label, text_x, text_y);
        manager.allocator.free(number_string);

        buttons.append(.{ .rect = sdl.SDL_FRect{ .x = (float_i - @as(f32, @floatFromInt(row_number * view.current_date_info.row_size))) * w, .y = @as(f32, @floatFromInt(row_number + 1)) * h, .w = w, .h = h }, .function_id = 0, .arg = .{ .toggleDay_date = current_day_rect_jd } }) catch undefined;

        const events_for_day = view.events_for_month[@intFromFloat(current_day_rect_jd - view.current_date_info.first_of_the_month_jd)];
        _ = sdl.TTF_SetFontSize(font_cantarell, reference_font_size * 0.8);
        _ = renderEventList(events_for_day, .{ .x = @intFromFloat(@round((float_i - @as(f32, @floatFromInt(row_number * view.current_date_info.row_size))) * w)), .y = @intFromFloat(@round(text_y + text_height_float) + 2), .w = @intFromFloat(@round(w)), .h = @intFromFloat(@round(0.95 * h - text_height_float)) });
    }
}
fn renderDayView() void {
    _ = sdl.SDL_SetRenderDrawColor(ren, color_background[0], color_background[1], color_background[2], color_background[3]);
    _ = sdl.SDL_RenderClear(ren);

    var current_y = renderCalendarTopBar();

    const events_for_day = view.events_for_month[@intFromFloat(view.current_jd - view.current_date_info.first_of_the_month_jd)];
    if (events_for_day.len != 0) {
        var text_width: c_int = undefined;
        var text_height: c_int = undefined;
        _ = sdl.TTF_SetFontSize(font_baloo2, reference_font_size * 2);

        if (settings.primary_calendar == .Gregorian) { // TODO: Choose a better font
            const sun_trs_days = astronomy.getTimeOfSunTransitRiseSet(view.current_jd, true, true, true);
            var sun_trs_dates = [3]dates.Date{ view.current_date_info.main_date, view.current_date_info.main_date, view.current_date_info.main_date };
            sun_trs_dates[0].day += sun_trs_days[0] + settings.utc_offset / 24;
            sun_trs_dates[1].day += sun_trs_days[1] + settings.utc_offset / 24;
            sun_trs_dates[2].day += sun_trs_days[2] + settings.utc_offset / 24;

            const sun_position_text_value = std.fmt.allocPrint(manager.allocator, "{s}: {t}; {s}: {t}; {s}: {t}", .{ tl("Sunrise"), sun_trs_dates[1], tl("Transit"), sun_trs_dates[0], tl("Sunset"), sun_trs_dates[2] }) catch std.debug.panic("OOM", .{});
            const sun_position_text = sdl.TTF_CreateText(text_engine, font_baloo2, @ptrCast(sun_position_text_value.ptr), sun_position_text_value.len);
            _ = sdl.TTF_SetTextColor(sun_position_text, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
            _ = sdl.TTF_GetTextSize(sun_position_text, &text_width, &text_height);
            _ = sdl.TTF_DrawRendererText(sun_position_text, (width - @as(f32, @floatFromInt(text_width))) / 2, current_y);
            current_y += @floatFromInt(text_height);
        }

        const events_text = sdl.TTF_CreateText(text_engine, font_baloo2, @ptrCast(tl("Events").ptr), tl("Events").len);
        _ = sdl.TTF_SetTextColor(events_text, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
        _ = sdl.TTF_GetTextSize(events_text, &text_width, &text_height);
        _ = sdl.TTF_DrawRendererText(events_text, (width - @as(f32, @floatFromInt(text_width))) / 2, current_y);
        current_y += @floatFromInt(text_height);

        _ = sdl.TTF_SetFontSize(font_cantarell, reference_font_size * 1.3);
        current_y += renderEventList(events_for_day, .{ .x = 0, .y = @intFromFloat(@round(current_y)), .w = @intFromFloat(@round(width)), .h = @intFromFloat(@round(height - current_y)) });
    }
}
// Returns height of top bar
fn renderCalendarTopBar() f32 {
    var text_width: c_int = undefined;
    var text_height: c_int = undefined;

    const status_bar_margin = if (builtin.abi.isAndroid()) @as(f32, @floatFromInt(android_safe_area_rect.y)) else 0;

    _ = sdl.TTF_SetFontSize(font_piazzolla_sc, reference_font_size * 4);
    const current_date = sdl.TTF_CreateText(text_engine, font_piazzolla_sc, @ptrCast(view.current_date_string.ptr), view.current_date_string.len);
    _ = sdl.TTF_SetTextColor(current_date, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
    _ = sdl.TTF_GetTextSize(current_date, &text_width, &text_height);
    _ = sdl.TTF_DrawRendererText(current_date, (width - @as(f32, @floatFromInt(text_width))) / 2, status_bar_margin);
    const bar_height = status_bar_margin + @as(f32, @floatFromInt(text_height));

    const left_arrow = sdl.TTF_CreateText(text_engine, font_piazzolla_sc, "◀", 3);
    _ = sdl.TTF_SetTextColor(left_arrow, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
    _ = sdl.TTF_DrawRendererText(left_arrow, 0, status_bar_margin);
    buttons.append(.{ .rect = sdl.SDL_FRect{ .x = 0, .y = status_bar_margin, .w = width / 3, .h = bar_height }, .function_id = 1 }) catch undefined;

    buttons.append(.{ .rect = sdl.SDL_FRect{ .x = width / 3, .y = status_bar_margin, .w = width / 3, .h = bar_height }, .function_id = 4, .arg = .{ .toggleDialog_id = view.dialog_go_to } }) catch undefined;

    const right_arrow = sdl.TTF_CreateText(text_engine, font_piazzolla_sc, "▶", 3);
    _ = sdl.TTF_SetTextColor(right_arrow, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
    _ = sdl.TTF_GetTextSize(right_arrow, &text_width, &text_height);
    _ = sdl.TTF_DrawRendererText(right_arrow, width - @as(f32, @floatFromInt(text_width)), status_bar_margin);
    buttons.append(.{ .rect = sdl.SDL_FRect{ .x = width * 2 / 3, .y = status_bar_margin, .w = width, .h = bar_height }, .function_id = 2 }) catch undefined;

    _ = sdl.TTF_SetFontSize(font_piazzolla_sc, reference_font_size * 1.5);
    const full_current_date = sdl.TTF_CreateText(text_engine, font_piazzolla_sc, @ptrCast(view.full_current_date_string.ptr), view.full_current_date_string.len);
    _ = sdl.TTF_SetTextColor(full_current_date, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
    _ = sdl.TTF_GetTextSize(full_current_date, &text_width, &text_height);
    _ = sdl.TTF_DrawRendererText(full_current_date, (width - @as(f32, @floatFromInt(text_width))) / 2, status_bar_margin);

    if ((view.is_day_view and settings.show_secondary_date_in_day_view) or (!view.is_day_view and settings.show_secondary_date_in_month_view)) {
        _ = sdl.TTF_SetFontSize(font_piazzolla_sc, reference_font_size * 1);
        const full_current_secondary_date = sdl.TTF_CreateText(text_engine, font_piazzolla_sc, @ptrCast(view.full_current_secondary_date_string.ptr), view.full_current_secondary_date_string.len);
        _ = sdl.TTF_SetTextColor(full_current_secondary_date, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
        _ = sdl.TTF_GetTextSize(full_current_secondary_date, &text_width, &text_height);
        _ = sdl.TTF_DrawRendererText(full_current_secondary_date, (width - @as(f32, @floatFromInt(text_width))) / 2, bar_height - @as(f32, @floatFromInt(text_height)));
    }

    return bar_height;
}
// Returns height of event list
fn renderEventList(evs: []const []const u8, available_rect: sdl.SDL_Rect) f32 {
    const original_render_viewport: [*c]sdl.SDL_Rect = null;
    if (sdl.SDL_RenderViewportSet(ren)) _ = sdl.SDL_GetRenderViewport(ren, original_render_viewport);
    _ = sdl.SDL_SetRenderViewport(ren, &available_rect);

    const available_width: f32 = @floatFromInt(available_rect.w);
    var current_y: f32 = 0;
    for (evs) |ev| {
        var arguments = std.mem.splitSequence(u8, ev, ";");
        _ = arguments.next();
        _ = arguments.next();
        _ = arguments.next();
        _ = arguments.next();
        _ = arguments.next();
        _ = arguments.next();
        const title = arguments.next().?;
        const background_color = parseColor(arguments.next().?);
        const text_color = parseColor(arguments.next().?);

        const label = sdl.TTF_CreateText(text_engine, font_cantarell, @ptrCast(title.ptr), title.len);
        var text_width: c_int = undefined;
        var text_height: c_int = undefined;
        _ = sdl.TTF_GetTextSize(label, &text_width, &text_height);
        const text_width_float: f32 = @floatFromInt(text_width);
        const text_height_float: f32 = @floatFromInt(text_height);

        _ = sdl.SDL_SetRenderDrawColor(ren, background_color[0], background_color[1], background_color[2], background_color[3]);
        _ = sdl.SDL_RenderFillRect(ren, &sdl.SDL_FRect{ .x = 0 + available_width / 30 + 2, .y = current_y, .w = available_width * 14 / 15 - 4, .h = text_height_float });
        _ = sdl.SDL_RenderFillRect(ren, &sdl.SDL_FRect{ .x = 0 + available_width / 30 + 1, .y = current_y + 1, .w = available_width * 14 / 15 - 2, .h = text_height_float - 2 });
        _ = sdl.SDL_RenderFillRect(ren, &sdl.SDL_FRect{ .x = 0 + available_width / 30, .y = current_y + 2, .w = available_width * 14 / 15, .h = text_height_float - 4 });

        _ = sdl.TTF_SetTextColor(label, text_color[0], text_color[1], text_color[2], text_color[3]);
        _ = sdl.TTF_DrawRendererText(label, 0 + available_width / 2 - text_width_float / 2, current_y);

        current_y += text_height_float + 2;
    }

    _ = sdl.SDL_SetRenderViewport(ren, original_render_viewport);
    return current_y;
}

// Dialogs
fn renderGoToDialog() void {
    buttons.clearAndFree();

    var text_width: c_int = undefined;
    var text_height: c_int = undefined;

    const dialog_width = if (width >= height) width / 3.5 else width / 1.05;
    const dialog_height = 5.2 * reference_font_size;
    var current_y = (height - dialog_height) / 2;
    renderDialogBase(&.{ .x = (width - dialog_width) / 2, .y = current_y, .w = dialog_width, .h = dialog_height }, std.math.sqrt(dialog_width * dialog_width + dialog_height * dialog_height) / 50);

    _ = sdl.TTF_SetFontSize(font_cantarell, reference_font_size * 2);
    const title_text = sdl.TTF_CreateText(text_engine, font_cantarell, @ptrCast(tl("Go to").ptr), tl("Go to").len);
    _ = sdl.TTF_SetTextColor(title_text, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
    _ = sdl.TTF_GetTextSize(title_text, &text_width, &text_height);
    _ = sdl.TTF_DrawRendererText(title_text, (width - @as(f32, @floatFromInt(text_width))) / 2, current_y);
    current_y += @floatFromInt(text_height);

    current_y += 0.3 * reference_font_size;

    renderTextInput(.{ .x = (width - dialog_width) / 2 + (dialog_width / 20), .y = current_y, .w = dialog_width - (dialog_width / 10), .h = 1.85 * reference_font_size }, view.full_current_date_string, true, reference_font_size * 1.5, "go_to");
    current_y += 1.85 * reference_font_size;
}
fn renderSettingsDialog(dialog_id: u8) void {
    buttons.clearAndFree();

    var text_width: c_int = undefined;

    const dialog_width: f32 = if (width >= height) width / 3 else width / 1.05;
    var dialog_height: f32 = 0;
    if (dialog_id == view.dialog_settings_general) {
        dialog_height = (0.85 + 2.5 + 1.5 + 1.3 + 5 * 1.1 + 5 * 1.85 + 4 * 0.6) * reference_font_size;
    } else if (dialog_id == view.dialog_settings_display) {
        dialog_height = (0.85 + 2.5 + 1.5 + 1.3 + 5 * 1.1 + 5 * 1.85 + 4 * 0.6) * reference_font_size;
    } else if (dialog_id == view.dialog_settings_events) {
        dialog_height = (0.85 + 2.5 + 1.5 + 1.3 + 4 * 1.1 + 4 * 1.85 + 3 * 0.6) * reference_font_size;
    } else if (dialog_id == view.dialog_settings_gregorian) {
        dialog_height = (0.85 + 2.5 + 1.5 + 1.3 + 4 * 1.1 + 4 * 1.85 + 3 * 0.6) * reference_font_size;
    } else if (dialog_id == view.dialog_settings_attic) {
        dialog_height = (0.85 + 2.5 + 1.5 + 1.3 + 4 * 1.1 + 4 * 1.85 + 3 * 0.6) * reference_font_size;
    }
    var current_y = (height - dialog_height) / 2;
    const dialog_rect: sdl.SDL_FRect = .{ .x = (width - dialog_width) / 2, .y = current_y, .w = dialog_width, .h = dialog_height };
    renderDialogBase(&dialog_rect, std.math.sqrt(dialog_width * dialog_width + dialog_height * dialog_height) / 50);

    _ = sdl.TTF_SetFontSize(font_cantarell, reference_font_size * 2);
    const title_text = sdl.TTF_CreateText(text_engine, font_cantarell, @ptrCast(tl("Settings").ptr), tl("Settings").len);
    _ = sdl.TTF_SetTextColor(title_text, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
    _ = sdl.TTF_GetTextSize(title_text, &text_width, null);
    _ = sdl.TTF_DrawRendererText(title_text, (width - @as(f32, @floatFromInt(text_width))) / 2, current_y);
    current_y += 2.25 * reference_font_size;

    const side_margin = (dialog_width / 20);
    const input_margin = reference_font_size * 0.6;
    const input_font_size = reference_font_size * 1.5;
    const label_font_size = reference_font_size * 1.2;
    var input_rect: sdl.SDL_FRect = .{ .x = dialog_rect.x + side_margin, .y = current_y, .w = dialog_width - side_margin * 2, .h = 1.85 * reference_font_size };
    var label_rect: sdl.SDL_FRect = .{ .x = dialog_rect.x + side_margin, .y = current_y, .w = dialog_width - side_margin * 2, .h = 1.1 * reference_font_size };

    const names = [_][]const u8{ tl("General"), tl("Display"), tl("Events"), tl("Gregorian"), tl("Attic") };
    const ids = [_]u8{ view.dialog_settings_general, view.dialog_settings_display, view.dialog_settings_events, view.dialog_settings_gregorian, view.dialog_settings_attic };
    _ = sdl.TTF_SetFontSize(font_cantarell, reference_font_size * 1.2);
    _ = sdl.SDL_SetRenderDrawColor(ren, color_background[0], color_background[1], color_background[2], color_background[3]);
    for (names, ids, 0..) |name, id, i| {
        const divisor: f32 = if (i < 3) 3 else 2;
        const center_x = dialog_rect.x + side_margin + (dialog_rect.w - 2 * side_margin) * ((@mod(@as(f32, @floatFromInt(i)), divisor) + 0.5) / divisor);
        if (i == 3) current_y += 1.3 * reference_font_size;

        const label_text = sdl.TTF_CreateText(text_engine, font_cantarell, @ptrCast(name.ptr), name.len);
        _ = sdl.TTF_SetTextColor(label_text, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
        _ = sdl.TTF_GetTextSize(label_text, &text_width, null);
        const left_x = center_x - @as(f32, @floatFromInt(text_width)) / 2;

        if (id == view.open_dialog) _ = sdl.SDL_SetRenderDrawColor(ren, color_bright_background[0], color_bright_background[1], color_bright_background[2], color_bright_background[3]);
        _ = sdl.SDL_RenderFillRect(ren, &.{ .x = left_x, .y = current_y + 1.5 * reference_font_size - 2, .w = @as(f32, @floatFromInt(text_width)), .h = 2 });
        if (id == view.open_dialog) _ = sdl.SDL_SetRenderDrawColor(ren, color_background[0], color_background[1], color_background[2], color_background[3]);
        _ = sdl.TTF_DrawRendererText(label_text, left_x, current_y);

        if (id != view.open_dialog) buttons.append(.{ .rect = .{ .x = left_x, .y = current_y, .w = @floatFromInt(text_width), .h = 1.3 * reference_font_size }, .function_id = 4, .arg = .{ .toggleDialog_id = id } }) catch undefined;
    }

    current_y += 1.5 * reference_font_size;

    current_y += input_margin;

    // TODO: Freeing either of these causes OOM, why???
    const calendar_type_fields = std.meta.fieldNames(dates.CalendarType);
    var calendar_type_field_names = std.ArrayList([]const u8).init(manager.allocator);

    const language_dropdown_options = manager.allocator.alloc([]const u8, manager.translation_options.?.len + 2) catch std.debug.panic("OOM", .{});
    language_dropdown_options[0] = "eng";
    @memcpy(language_dropdown_options[1 .. language_dropdown_options.len - 1], manager.translation_options.?);
    language_dropdown_options[language_dropdown_options.len - 1] = tl("Download more language packs"); // TODO: Make this work

    for (calendar_type_fields) |field| calendar_type_field_names.append(tl(field)) catch std.debug.panic("OOM", .{});
    if (dialog_id == view.dialog_settings_general) {
        label_rect.y = current_y;
        _ = renderLabel(label_rect, tl("Primary calendar"), label_font_size);
        current_y += label_rect.h;
        input_rect.y = current_y;
        renderDropdownInput(
            input_rect,
            tl(@tagName(settings.primary_calendar)),
            input_font_size,
            "settings_primary_calendar",
            calendar_type_field_names.items,
        );
        current_y += input_rect.h + input_margin;

        label_rect.y = current_y;
        _ = renderLabel(label_rect, tl("Secondary calendar"), label_font_size);
        current_y += label_rect.h;
        input_rect.y = current_y;
        renderDropdownInput(
            input_rect,
            tl(@tagName(settings.secondary_calendar)),
            input_font_size,
            "settings_secondary_calendar",
            calendar_type_field_names.items,
        );
        current_y += input_rect.h + input_margin;

        label_rect.y = current_y;
        _ = renderLabel(label_rect, tl("Anniversary calendar"), label_font_size);
        current_y += label_rect.h;
        input_rect.y = current_y;
        renderBoolInput(
            input_rect,
            &settings.anniversary_calendar,
            tl("Primary"),
            tl("Secondary"),
            input_font_size,
        );
        current_y += input_rect.h + input_margin;

        label_rect.y = current_y;
        _ = renderLabel(label_rect, tl("Latitude (°N)"), label_font_size);
        _ = renderLabel(.{ .x = label_rect.x + label_rect.w / 2, .y = label_rect.y, .w = label_rect.w, .h = label_rect.h }, tl("Longitude (°E)"), label_font_size);
        current_y += label_rect.h;
        input_rect.y = current_y;
        const latitude_string = std.fmt.allocPrint(manager.allocator, "{d}", .{settings.latitude}) catch std.debug.panic("OOM", .{});
        const longitude_string = std.fmt.allocPrint(manager.allocator, "{d}", .{settings.longitude}) catch std.debug.panic("OOM", .{});
        renderTextInput(
            .{ .x = input_rect.x, .y = input_rect.y, .w = input_rect.w / 2 - side_margin / 4, .h = input_rect.h },
            latitude_string,
            false,
            input_font_size,
            "settings_latitude",
        );
        renderTextInput(
            .{ .x = input_rect.x + input_rect.w / 2, .y = input_rect.y, .w = input_rect.w / 2 - side_margin / 2, .h = input_rect.h },
            longitude_string,
            false,
            input_font_size,
            "settings_longitude",
        );
        manager.allocator.free(latitude_string);
        manager.allocator.free(longitude_string);
        current_y += input_rect.h + input_margin;

        label_rect.y = current_y;
        _ = renderLabel(label_rect, tl("UTC offset"), label_font_size);
        current_y += label_rect.h;
        input_rect.y = current_y;
        const utc_offset_string = std.fmt.allocPrint(manager.allocator, "{d}", .{settings.utc_offset}) catch std.debug.panic("OOM", .{});
        renderTextInput(
            input_rect,
            utc_offset_string,
            false,
            input_font_size,
            "settings_utc_offset",
        );
        manager.allocator.free(utc_offset_string);
        current_y += input_rect.h + input_margin;
    } else if (dialog_id == view.dialog_settings_display) {
        label_rect.y = current_y;
        _ = renderLabel(label_rect, tl("Language"), label_font_size);
        current_y += label_rect.h;
        input_rect.y = current_y;
        renderDropdownInput(
            input_rect,
            settings.language orelse "eng",
            input_font_size,
            "settings_language",
            language_dropdown_options,
        );
        current_y += input_rect.h + input_margin;

        label_rect.y = current_y;
        _ = renderLabel(label_rect, tl("Light mode"), label_font_size);
        current_y += label_rect.h;
        input_rect.y = current_y;
        renderBoolInput(
            input_rect,
            &settings.light_mode,
            tl("On"),
            tl("Off"),
            input_font_size,
        );
        current_y += input_rect.h + input_margin;

        label_rect.y = current_y;
        _ = renderLabel(label_rect, tl("Secondary date in day view"), label_font_size);
        current_y += label_rect.h;
        input_rect.y = current_y;
        renderBoolInput(
            input_rect,
            &settings.show_secondary_date_in_day_view,
            tl("On"),
            tl("Off"),
            input_font_size,
        );
        current_y += input_rect.h + input_margin;

        label_rect.y = current_y;
        _ = renderLabel(label_rect, tl("In month view"), label_font_size);
        current_y += label_rect.h;
        input_rect.y = current_y;
        renderBoolInput(
            input_rect,
            &settings.show_secondary_date_in_month_view,
            tl("On"),
            tl("Off"),
            input_font_size,
        );
        current_y += input_rect.h + input_margin;

        label_rect.y = current_y;
        _ = renderLabel(label_rect, tl("For days in month view"), label_font_size);
        current_y += label_rect.h;
        input_rect.y = current_y;
        renderBoolInput(
            input_rect,
            &settings.show_secondary_date_for_days_in_month_view,
            tl("On"),
            tl("Off"),
            input_font_size,
        );
        current_y += input_rect.h + input_margin;
    } else if (dialog_id == view.dialog_settings_events) {} else if (dialog_id == view.dialog_settings_gregorian) {} else if (dialog_id == view.dialog_settings_attic) {}

    renderDropdownOnTop();
}
fn renderDialogBase(rect: *const sdl.SDL_FRect, radius: f32) void {
    _ = sdl.SDL_SetRenderDrawBlendMode(ren, sdl.SDL_BLENDMODE_BLEND);
    _ = sdl.SDL_SetRenderDrawColor(ren, 0, 0, 0, 100);
    renderRoundedRect(&.{ .x = rect.x + reference_font_size / 1.5, .y = rect.y + reference_font_size / 1.5, .w = rect.w, .h = rect.h }, radius);
    _ = sdl.SDL_SetRenderDrawBlendMode(ren, sdl.SDL_BLENDMODE_NONE);
    _ = sdl.SDL_SetRenderDrawColor(ren, color_bright_background[0], color_bright_background[1], color_bright_background[2], color_bright_background[3]);
    renderRoundedRect(&.{ .x = rect.x - 2, .y = rect.y - 2, .w = rect.w + 4, .h = rect.h + 4 }, radius);
    _ = sdl.SDL_SetRenderDrawColor(ren, color_dark_background[0], color_dark_background[1], color_dark_background[2], color_dark_background[3]);
    renderRoundedRect(rect, radius);

    buttons.append(.{ .rect = .{ .x = 0, .y = 0, .w = rect.x, .h = height }, .function_id = 4, .arg = .{ .toggleDialog_id = view.open_dialog } }) catch std.debug.panic("OOM", .{});
    buttons.append(.{ .rect = .{ .x = rect.x + rect.w, .y = 0, .w = width - rect.x - rect.w, .h = height }, .function_id = 4, .arg = .{ .toggleDialog_id = view.open_dialog } }) catch std.debug.panic("OOM", .{});
    buttons.append(.{ .rect = .{ .x = rect.x, .y = 0, .w = rect.w, .h = rect.y }, .function_id = 4, .arg = .{ .toggleDialog_id = view.open_dialog } }) catch std.debug.panic("OOM", .{});
    buttons.append(.{ .rect = .{ .x = rect.x, .y = rect.y + rect.h, .w = rect.w, .h = height - rect.y - rect.h }, .function_id = 4, .arg = .{ .toggleDialog_id = view.open_dialog } }) catch std.debug.panic("OOM", .{});
}
fn renderRoundedRect(rect: *const sdl.SDL_FRect, radius: f32) void {
    const radius_ = radius + 1; // Idk, it's off, probably just an artifact of the circle algorithm
    _ = sdl.SDL_RenderFillRect(ren, &.{ .x = rect.x, .y = rect.y + radius_, .w = radius_, .h = rect.h - 2 * radius_ });
    _ = sdl.SDL_RenderFillRect(ren, &.{ .x = rect.x + rect.w - radius_, .y = rect.y + radius_, .w = radius_, .h = rect.h - 2 * radius_ });
    _ = sdl.SDL_RenderFillRect(ren, &.{ .x = rect.x + radius_, .y = rect.y, .w = rect.w - 2 * radius_, .h = rect.h });

    const x_multiplier = [_]f32{ 1, 1, -1, -1 };
    const y_multiplier = [_]f32{ 1, -1, -1, 1 };
    const cx = [_]f32{ rect.x + rect.w - radius - 1, rect.x + rect.w - radius - 1, rect.x + radius, rect.x + radius };
    const cy = [_]f32{ rect.y + radius, rect.y + rect.h - radius - 1, rect.y + rect.h - radius - 1, rect.y + radius };
    for (0..4) |i| {
        var x: f32 = 0;
        var y: f32 = -radius;
        _ = sdl.SDL_RenderLine(ren, cx[i] - y * x_multiplier[i], cy[i] - x * y_multiplier[i], cx[i] - y * x_multiplier[i], cy[i]);
        while (x < -y) {
            const y_mid = y + 0.5;
            if (x * x + y_mid * y_mid > radius * radius) {
                y += 1;
                _ = sdl.SDL_RenderLine(ren, cx[i] - y * x_multiplier[i], cy[i] - x * y_multiplier[i], cx[i] - y * x_multiplier[i], cy[i]);
            }
            _ = sdl.SDL_RenderLine(ren, cx[i] + x * x_multiplier[i], cy[i] + y * y_multiplier[i], cx[i] + x * x_multiplier[i], cy[i]);
            // _ = sdl.SDL_RenderPoint(ren, cx[i] + x * x_multiplier[i], cy[i] + y * y_multiplier[i]);
            // _ = sdl.SDL_RenderPoint(ren, cx[i] - y * x_multiplier[i], cy[i] - x * y_multiplier[i]);
            x += 1;
        }
    }
}
// Not to be called directly, use renderTextInput or renderDropdownInput
fn renderTextInputFromButton(placeholder: []const u8, bleach_placeholder: bool, button: ButtonStruct) void {
    const original_render_viewport: [*c]sdl.SDL_Rect = null;
    if (sdl.SDL_RenderViewportSet(ren)) _ = sdl.SDL_GetRenderViewport(ren, original_render_viewport);
    _ = sdl.SDL_SetRenderViewport(ren, &.{ .x = @intFromFloat(@round(button.rect.x)), .y = @intFromFloat(@round(button.rect.y)), .w = @intFromFloat(@round(button.rect.w)), .h = @intFromFloat(@round(button.rect.h)) });

    _ = sdl.TTF_SetFontSize(font_cantarell, button.arg.text_input_font_size.?);
    const left_padding = std.math.sqrt(button.rect.x * button.rect.x + button.rect.y * button.rect.y) / 75;

    const is_input_active = current_text_input != null and std.mem.eql(u8, current_text_input.?.arg.text_input_id.?, button.arg.text_input_id.?);
    var render_placeholder = true;

    if (!is_input_active) {
        buttons.append(button) catch std.debug.panic("OOM", .{});
        _ = sdl.SDL_SetRenderDrawColor(ren, color_background[0], color_background[1], color_background[2], color_background[3]);
    } else {
        if (current_text_input_value.items.len != 0) render_placeholder = false;
        _ = sdl.SDL_SetRenderDrawColor(ren, color_bright_background[0], color_bright_background[1], color_bright_background[2], color_bright_background[3]);
    }
    _ = sdl.SDL_RenderFillRect(ren, &.{ .x = 0, .y = button.rect.h - 2, .w = button.rect.w, .h = 2 });

    if (render_placeholder) {
        const placeholder_text = sdl.TTF_CreateText(text_engine, font_cantarell, @ptrCast(placeholder.ptr), placeholder.len);
        _ = if (bleach_placeholder) sdl.TTF_SetTextColor(placeholder_text, color_contrast_bleached[0], color_contrast_bleached[1], color_contrast_bleached[2], color_contrast_bleached[3]) else sdl.TTF_SetTextColor(placeholder_text, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
        _ = sdl.TTF_DrawRendererText(placeholder_text, left_padding, 0);
    } else {
        const null_terminated_value = manager.allocator.alloc(u8, current_text_input_value.items.len + 1) catch undefined;
        @memcpy(null_terminated_value[0..current_text_input_value.items.len], current_text_input_value.items);
        null_terminated_value[current_text_input_value.items.len] = 0;

        const input_text = sdl.TTF_CreateText(text_engine, font_cantarell, @ptrCast(null_terminated_value.ptr), null_terminated_value.len);
        _ = sdl.TTF_SetTextColor(input_text, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
        _ = sdl.TTF_DrawRendererText(input_text, left_padding, 0);
        manager.allocator.free(null_terminated_value);
    }

    _ = sdl.SDL_SetRenderViewport(ren, original_render_viewport);
}
fn renderTextInput(rect: sdl.SDL_FRect, placeholder: []const u8, bleach_placeholder: bool, font_size: f32, id: []const u8) void {
    const button: ButtonStruct = .{ .rect = rect, .function_id = 3, .arg = .{ .text_input_font_size = font_size, .text_input_id = id } };
    renderTextInputFromButton(placeholder, bleach_placeholder, button);
}
fn renderDropdownInput(rect: sdl.SDL_FRect, value: []const u8, font_size: f32, id: []const u8, dropdown_options: []const []const u8) void {
    const button: ButtonStruct = .{ .rect = rect, .function_id = 3, .arg = .{ .text_input_font_size = font_size, .text_input_id = id, .dropdown_input_options = dropdown_options } };
    renderTextInputFromButton(value, false, button);
}
fn renderLabel(rect: sdl.SDL_FRect, value: []const u8, font_size: f32) *sdl.TTF_Text {
    _ = sdl.TTF_SetFontSize(font_cantarell, font_size);
    const label_text = sdl.TTF_CreateText(text_engine, font_cantarell, @ptrCast(value.ptr), value.len);
    _ = sdl.TTF_SetTextColor(label_text, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
    _ = sdl.TTF_DrawRendererText(label_text, rect.x, rect.y);
    return label_text;
}
fn renderBoolInput(rect: sdl.SDL_FRect, value: *bool, on_text: []const u8, off_text: []const u8, font_size: f32) void {
    _ = sdl.SDL_SetRenderDrawColor(ren, color_background[0], color_background[1], color_background[2], color_background[3]);
    _ = sdl.SDL_RenderFillRect(ren, &.{ .x = rect.x, .y = rect.y + rect.h - 2, .w = rect.w, .h = 2 });

    const left_padding = std.math.sqrt(rect.x * rect.x + rect.y * rect.y) / 75;
    const value_text_string = if (value.*) on_text else off_text;
    _ = sdl.TTF_SetFontSize(font_cantarell, font_size);
    const value_text = sdl.TTF_CreateText(text_engine, font_cantarell, @ptrCast(value_text_string.ptr), value_text_string.len);
    _ = sdl.TTF_SetTextColor(value_text, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
    _ = sdl.TTF_DrawRendererText(value_text, rect.x + left_padding, rect.y);

    buttons.append(.{ .rect = rect, .function_id = 6, .arg = .{ .bool_input_value = value } }) catch std.debug.panic("OOM", .{});
}
// Renders the dropdown of the currently active, if any, dropdown input, to be called after any other rendering as it should be on top of everything
fn renderDropdownOnTop() void {
    if (current_text_input != null and current_text_input.?.arg.dropdown_input_options != null) {
        buttons.clearAndFree();
        const rect = current_text_input.?.rect;
        const left_padding = std.math.sqrt(rect.x * rect.x + rect.y * rect.y) / 100;
        const option_height = rect.h;
        const option_count = current_text_input.?.arg.dropdown_input_options.?.len;

        var current_y = rect.y + rect.h;
        var text_width: c_int = undefined;
        var text_height: c_int = undefined;
        _ = sdl.SDL_SetRenderDrawColor(ren, color_bright_background[0], color_bright_background[1], color_bright_background[2], color_bright_background[3]);
        for (current_text_input.?.arg.dropdown_input_options.?, 0..) |option, i| {
            const lower_option = std.ascii.allocLowerString(manager.allocator, option) catch std.debug.panic("OOM", .{});
            const lower_current_text_input_value = std.ascii.allocLowerString(manager.allocator, current_text_input_value.items) catch std.debug.panic("OOM", .{});
            if (current_text_input_value.items.len == 0 or std.mem.startsWith(u8, lower_option, lower_current_text_input_value)) { // Option search
                if (i != option_count - 1) {
                    _ = sdl.SDL_RenderFillRect(ren, &.{ .x = rect.x, .y = current_y, .w = rect.w, .h = option_height });
                } else {
                    renderRoundedRect(&.{ .x = rect.x, .y = current_y, .w = rect.w, .h = option_height }, left_padding);
                    _ = sdl.SDL_RenderFillRect(ren, &.{ .x = rect.x, .y = current_y, .w = rect.w, .h = left_padding });
                }

                _ = sdl.TTF_SetFontSize(font_cantarell, current_text_input.?.arg.text_input_font_size.?);
                const option_text = sdl.TTF_CreateText(text_engine, font_cantarell, @ptrCast(option.ptr), option.len);
                _ = sdl.TTF_SetTextColor(option_text, color_contrast[0], color_contrast[1], color_contrast[2], color_contrast[3]);
                _ = sdl.TTF_GetTextSize(option_text, &text_width, &text_height);
                _ = sdl.TTF_DrawRendererText(option_text, rect.x + left_padding, current_y);

                buttons.append(.{ .rect = sdl.SDL_FRect{ .x = rect.x, .y = current_y, .w = rect.w, .h = option_height }, .function_id = 5, .arg = .{ .dropdown_option_value = option } }) catch std.debug.panic("OOM", .{});

                current_y += option_height;
            }
            manager.allocator.free(lower_option);
            manager.allocator.free(lower_current_text_input_value);
        }
    }
}
fn startTextInput(button: ButtonStruct) void {
    current_text_input = button;
    _ = sdl.SDL_StartTextInput(window);
    updateView();
}
pub fn confirmTextInput() void {
    if (current_text_input == null) return;
    if (std.mem.eql(u8, current_text_input.?.arg.text_input_id.?, "go_to")) {
        const date: ?dates.Date = dates.Date.parse(settings.primary_calendar, current_text_input_value.items) catch null;
        if (date != null) {
            const parsed_date = dates.dateToJD(date.?, true, false) catch dates.now();
            if (@abs(parsed_date - dates.now()) <= 36525) {
                view.current_jd = parsed_date;
                view.refreshCurrentDateInfo();
            }
            view.toggleDialog(view.dialog_go_to);
        }
    } else if (std.mem.startsWith(u8, current_text_input.?.arg.text_input_id.?, "settings_")) {
        if (std.mem.eql(u8, current_text_input.?.arg.text_input_id.?, "settings_primary_calendar")) {
            settings.primary_calendar = std.meta.stringToEnum(dates.CalendarType, manager.translateToEnglish(current_text_input_value.items)) orelse settings.primary_calendar;
        } else if (std.mem.eql(u8, current_text_input.?.arg.text_input_id.?, "settings_secondary_calendar")) {
            settings.secondary_calendar = std.meta.stringToEnum(dates.CalendarType, manager.translateToEnglish(current_text_input_value.items)) orelse settings.secondary_calendar;
        } else if (std.mem.eql(u8, current_text_input.?.arg.text_input_id.?, "settings_latitude")) {
            settings.latitude = std.math.clamp(std.fmt.parseFloat(f64, current_text_input_value.items) catch settings.latitude, -90, 90);
        } else if (std.mem.eql(u8, current_text_input.?.arg.text_input_id.?, "settings_longitude")) {
            settings.longitude = std.math.clamp(std.fmt.parseFloat(f64, current_text_input_value.items) catch settings.longitude, -180, 180);
        } else if (std.mem.eql(u8, current_text_input.?.arg.text_input_id.?, "settings_utc_offset")) {
            settings.utc_offset = std.math.clamp(std.fmt.parseFloat(f64, current_text_input_value.items) catch settings.utc_offset, -12, 14);
        } else if (std.mem.eql(u8, current_text_input.?.arg.text_input_id.?, "settings_language")) {
            if (std.mem.eql(u8, current_text_input_value.items, "eng")) {
                if (settings.language != null) {
                    manager.allocator.free(settings.language.?);
                    settings.language = null;
                }
            } else if (manager.indexOfStringArray(manager.translation_options.?, current_text_input_value.items) != null) {
                if (settings.language != null) {
                    manager.allocator.free(settings.language.?);
                    settings.language = null;
                }
                settings.language = manager.allocator.alloc(u8, current_text_input_value.items.len) catch std.debug.panic("OOM", .{});
                @memcpy(settings.language.?, current_text_input_value.items);
            }
        }
        settings.saveSettings() catch |err| std.debug.panic("Error saving settings: {}", .{err});
        settings.updateSettings() catch |err| std.debug.panic("Error updating settings: {}", .{err});
    }
    current_text_input = null;
    current_text_input_value.clearAndFree();
    _ = sdl.SDL_StopTextInput(window);
    updateView();
}

// Colors
var color_bright_background = [4]u8{ 57, 63, 38, 255 }; // #393f26
var color_background = [4]u8{ 33, 38, 19, 255 }; // #212613
var color_dark_background = [4]u8{ 21, 25, 10, 255 }; // #15190a
var color_contrast = [4]u8{ 242, 236, 218, 255 }; // #f2ecda
var color_contrast_bleached = [4]u8{ 160, 156, 144, 255 };
pub fn updateLightMode() void {
    if (!settings.light_mode) {
        color_bright_background = [4]u8{ 57, 63, 38, 255 }; // #393f26
        color_background = [4]u8{ 33, 38, 19, 255 }; // #212613
        color_dark_background = [4]u8{ 21, 25, 10, 255 }; // #15190a
        color_contrast = [4]u8{ 242, 236, 218, 255 }; // #f2ecda
        color_contrast_bleached = [4]u8{ 160, 156, 144, 255 };
    } else {
        color_bright_background = [4]u8{ 18, 102, 10, 255 }; // #12660a
        color_background = [4]u8{ 204, 197, 184, 255 }; // #ccc5b8
        color_dark_background = [4]u8{ 179, 172, 161, 255 }; // #b3aca1
        color_contrast = [4]u8{ 2, 8, 1, 255 }; // #020801
        color_contrast_bleached = [4]u8{ 81, 79, 73, 255 };
    }
}
pub fn parseColor(string: []const u8) [4]u8 {
    if (string[0] == '#') { // #ffffff
        var color = [4]u8{ 255, 255, 255, 255 };
        if (string.len == 4 or string.len == 5) { // #fff or #ffff
            for (1..string.len) |i| {
                const element = std.mem.join(manager.allocator, "", &.{ string[i .. i + 1], "0" }) catch std.debug.panic("OOM", .{});
                color[i - 1] = std.fmt.parseInt(u8, element, 16) catch 255;
                manager.allocator.free(element);
            }
        } else if (string.len == 7 or string.len == 9) { // #ffffff or #ffffffff
            for (1..(string.len + 1) / 2) |i| {
                color[i - 1] = std.fmt.parseInt(u8, string[i * 2 - 1 .. i * 2 + 1], 16) catch 255;
            }
        }
        return color;
    } else if (std.ascii.isAlphabetic(string[0])) {
        return if (std.mem.eql(u8, string, "bright_background"))
            color_bright_background
        else if (std.mem.eql(u8, string, "background"))
            color_background
        else if (std.mem.eql(u8, string, "dark_background"))
            color_dark_background
        else if (std.mem.eql(u8, string, "contrast"))
            color_contrast
        else
            [4]u8{ 255, 255, 255, 255 };
    } else { // 255,255,255,255
        var string_split = std.mem.splitSequence(u8, string, ",");
        return [4]u8{ std.fmt.parseInt(u8, string_split.next().?, 0) catch 255, std.fmt.parseInt(u8, string_split.next().?, 0) catch 255, std.fmt.parseInt(u8, string_split.next().?, 0) catch 255, std.fmt.parseInt(u8, string_split.next() orelse "255", 0) catch 255 };
    }
}

pub fn getPrefPath() []u8 {
    return std.mem.span(sdl.SDL_GetPrefPath("Epigeos", "Reo"));
}
