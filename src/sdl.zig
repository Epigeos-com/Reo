const std = @import("std");
pub const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});
const builtin = @import("builtin");

const view = @import("view.zig");
const manager = @import("manager.zig");
const settings = @import("settings.zig");
const dates = @import("dates.zig");
const astronomy = @import("astronomy.zig");
const events = @import("events.zig");

const file_icon_bmp = @embedFile("assets/icon.bmp");
const file_cantarell_regular = @embedFile("assets/Cantarell-Regular.otf");
const file_piazzolla_light = @embedFile("assets/Piazzolla-Light.otf");
const file_piazzolla_sc_thin = @embedFile("assets/PiazzollaSC-Thin.otf");

var ren: ?*sdl.SDL_Renderer = undefined;
var text_engine: ?*sdl.TTF_TextEngine = undefined;
var width: f32 = undefined;
var height: f32 = undefined;
var android_safe_area_rect: sdl.SDL_Rect = undefined;
var reference_font_size: f32 = undefined;
var font_cantarell: ?*sdl.TTF_Font = undefined;
var font_piazzolla: ?*sdl.TTF_Font = undefined;
var font_piazzolla_sc: ?*sdl.TTF_Font = undefined;

var buttons = std.ArrayList(struct { rect: sdl.SDL_FRect, function_id: u8, arg: struct { arg_f64: f64 } = undefined }).init(manager.allocator);
var android_swipe_start_x: f32 = undefined;

pub fn main() void {
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO) or !sdl.TTF_Init()) {
        sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, sdl.SDL_GetError());
    }

    const flags: sdl.SDL_WindowFlags = sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_OPENGL;
    const window = sdl.SDL_CreateWindow("Reo", 1024, 576, flags);
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
                view.changeDateByOneUnit(event.button.x < android_swipe_start_x);
                android_swipe_start_x = undefined;
            } else if (event.type == sdl.SDL_EVENT_MOUSE_BUTTON_UP) {
                for (buttons.items) |button| {
                    if (isMouseWithinRect(event.button.x, event.button.y, button.rect)) {
                        switch (button.function_id) {
                            0 => view.toggleDay(button.arg.arg_f64),
                            1 => view.changeDateByOneUnit(false),
                            2 => view.changeDateByOneUnit(true),
                            else => sdl.SDL_LogCritical(sdl.SDL_LOG_CATEGORY_APPLICATION, "Invalid button function id"),
                        }
                        break;
                    }
                }
            } else if (event.type == sdl.SDL_EVENT_KEY_DOWN) {
                if (event.key.key == sdl.SDLK_LEFT) {
                    view.changeDateByOneUnit(false);
                } else if (event.key.key == sdl.SDLK_RIGHT) {
                    view.changeDateByOneUnit(true);
                } else if (event.key.key == sdl.SDLK_ESCAPE and view.is_day_view) {
                    view.toggleDay(-1);
                } else if (event.key.key == sdl.SDLK_AC_BACK) {
                    if (view.is_day_view) view.toggleDay(-1) else _ = sdl.SDL_MinimizeWindow(window);
                }
            }
        }
    }

    sdl.SDL_DestroyRenderer(ren);
    sdl.SDL_DestroyWindow(window);
    sdl.SDL_Quit();
}

pub fn updateView() void {
    buttons.clearAndFree();
    if (view.is_day_view) renderDayView() else renderMonthView();
}

fn renderMonthView() void {
    _ = sdl.SDL_SetRenderDrawColor(ren, 0, 0, 0, 255);
    _ = sdl.SDL_RenderClear(ren);

    const top_bar_height = renderCalendarTopBar();
    const space_above_grid = top_bar_height + if (builtin.abi.isAndroid()) @as(f32, @floatFromInt(android_safe_area_rect.y)) else 0;
    const month_grid_height = height - top_bar_height;

    const thickness: f32 = 2;
    _ = sdl.SDL_SetRenderScale(ren, thickness, thickness);

    const row_count = @max(view.current_date_info.min_rows, @divFloor(view.current_date_info.days_in_month, view.current_date_info.row_size));
    const h = (month_grid_height - thickness) / @as(f32, @floatFromInt(row_count));
    const w = (width - thickness) / @as(f32, @floatFromInt(view.current_date_info.row_size));
    _ = sdl.SDL_SetRenderDrawColor(ren, 255, 255, 255, 255);

    for (0..row_count + 1) |i| {
        const float_i: f32 = @floatFromInt(i);
        _ = sdl.SDL_RenderLine(ren, 0, (float_i * h + space_above_grid) / thickness, width / thickness, (float_i * h + space_above_grid) / thickness);
    }
    for (0..view.current_date_info.row_size + 1) |i| {
        const float_i: f32 = @floatFromInt(i);
        _ = sdl.SDL_RenderLine(ren, float_i * w / thickness, space_above_grid / thickness, float_i * w / thickness, (month_grid_height + space_above_grid) / thickness - 1);
    }

    _ = sdl.SDL_SetRenderScale(ren, 1, 1);

    const events_for_month = events.getEventsForDatesArray(manager.allocator, view.current_date_info.first_of_the_month_jd, view.current_date_info.first_of_the_month_jd + @as(f64, @floatFromInt(view.current_date_info.days_in_month)) - 1) catch &.{};
    var today = @floor(dates.now()) + 0.5;
    if (settings.primary_calendar == .Attic and today >= view.current_date_info.first_of_the_month_jd and today - 1 <= view.current_date_info.first_of_the_month_jd + @as(f64, @floatFromInt(view.current_date_info.days_in_month)) - 1) {
        if (dates.now() < today + astronomy.getTimeOfSunTransitRiseSet(today, false, true, false)[1]) today -= 1;
    }
    var secondary_date_info = dates.getDateInfo(settings.secondary_calendar, view.current_date_info.first_of_the_month_jd, false, false) catch undefined;
    var secondary_day_num = @as(u8, @intFromFloat(@floor(secondary_date_info.main_date.day))) - 1;
    for (0..view.current_date_info.days_in_month) |i| {
        const current_day_rect_jd = view.current_date_info.first_of_the_month_jd + @as(f64, @floatFromInt(i));

        var number_string: []u8 = undefined;
        if (settings.show_secondary_date_in_month_view) {
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
            _ = sdl.SDL_SetRenderDrawColor(ren, 0, 100, 0, 255);
            _ = sdl.SDL_RenderFillRect(ren, &sdl.SDL_FRect{ .x = text_x, .y = text_y, .w = text_width_float, .h = text_height_float });
            _ = sdl.SDL_RenderFillRect(ren, &sdl.SDL_FRect{ .x = text_x - 1, .y = text_y + 1, .w = text_width_float + 2, .h = text_height_float - 2 });
            _ = sdl.SDL_RenderFillRect(ren, &sdl.SDL_FRect{ .x = text_x - 2, .y = text_y + 2, .w = text_width_float + 4, .h = text_height_float - 4 });
        }

        _ = sdl.TTF_DrawRendererText(label, text_x, text_y);
        manager.allocator.free(number_string);

        buttons.append(.{ .rect = sdl.SDL_FRect{ .x = (float_i - @as(f32, @floatFromInt(row_number * view.current_date_info.row_size))) * w, .y = @as(f32, @floatFromInt(row_number + 1)) * h, .w = w, .h = h }, .function_id = 0, .arg = .{ .arg_f64 = current_day_rect_jd } }) catch undefined;

        _ = sdl.TTF_SetFontSize(font_cantarell, reference_font_size * 0.8);
        _ = renderEventList(events_for_month[@intFromFloat(current_day_rect_jd - view.current_date_info.first_of_the_month_jd)], (float_i - @as(f32, @floatFromInt(row_number * view.current_date_info.row_size))) * w, text_y + text_height_float, w);
    }
    manager.allocator.free(events_for_month);

    _ = sdl.SDL_RenderPresent(ren);
}
fn renderDayView() void {
    _ = sdl.SDL_SetRenderDrawColor(ren, 0, 0, 0, 255);
    _ = sdl.SDL_RenderClear(ren);

    var current_y = renderCalendarTopBar();

    // showSecondaryDateInDayView

    _ = sdl.TTF_SetFontSize(font_cantarell, reference_font_size * 1.3);
    // current_y += renderEventList(view.current_jd, 0, current_y, width);
    current_y += 0;

    _ = sdl.SDL_RenderPresent(ren);
}
// Returns height of top bar
fn renderCalendarTopBar() f32 {
    var text_width: c_int = undefined;
    var text_height: c_int = undefined;

    const status_bar_margin = if (builtin.abi.isAndroid()) @as(f32, @floatFromInt(android_safe_area_rect.y)) else 0;

    _ = sdl.TTF_SetFontSize(font_piazzolla_sc, reference_font_size * 4);
    const current_date = sdl.TTF_CreateText(text_engine, font_piazzolla_sc, @ptrCast(view.current_date_string.ptr), view.current_date_string.len);
    _ = sdl.TTF_GetTextSize(current_date, &text_width, &text_height);
    _ = sdl.TTF_DrawRendererText(current_date, (width - @as(f32, @floatFromInt(text_width))) / 2, status_bar_margin);
    const bar_height = @as(f32, @floatFromInt(text_height));

    const left_arrow = sdl.TTF_CreateText(text_engine, font_piazzolla_sc, "◀", view.full_current_date_string.len);
    _ = sdl.TTF_DrawRendererText(left_arrow, 0, status_bar_margin);
    buttons.append(.{ .rect = sdl.SDL_FRect{ .x = 0, .y = status_bar_margin, .w = width / 3, .h = bar_height }, .function_id = 1 }) catch undefined;

    const right_arrow = sdl.TTF_CreateText(text_engine, font_piazzolla_sc, "▶", view.full_current_date_string.len);
    _ = sdl.TTF_GetTextSize(right_arrow, &text_width, &text_height);
    _ = sdl.TTF_DrawRendererText(right_arrow, width - @as(f32, @floatFromInt(text_width)), status_bar_margin);
    buttons.append(.{ .rect = sdl.SDL_FRect{ .x = width * 2 / 3, .y = status_bar_margin, .w = width, .h = bar_height }, .function_id = 2 }) catch undefined;

    _ = sdl.TTF_SetFontSize(font_piazzolla_sc, reference_font_size * 1.5);
    const full_current_date = sdl.TTF_CreateText(text_engine, font_piazzolla_sc, @ptrCast(view.full_current_date_string.ptr), view.full_current_date_string.len);
    _ = sdl.TTF_GetTextSize(full_current_date, &text_width, &text_height);
    _ = sdl.TTF_DrawRendererText(full_current_date, (width - @as(f32, @floatFromInt(text_width))) / 2, status_bar_margin);

    return bar_height;
}
// Returns height of event list
fn renderEventList(evs: []const []const u8, starting_x: f32, starting_y: f32, available_width: f32) f32 {
    // TODO: add available_height with a mask and make it work with new event handling
    var current_y = starting_y;
    for (evs) |ev| {
        var arguments = std.mem.splitSequence(u8, ev, ";");
        _ = arguments.next();
        _ = arguments.next();
        _ = arguments.next();
        _ = arguments.next();
        _ = arguments.next();
        _ = arguments.next();
        const title = arguments.next().?;
        const background_color = arguments.next().?;
        const text_color = arguments.next().?;

        const label = sdl.TTF_CreateText(text_engine, font_cantarell, @ptrCast(title.ptr), title.len);
        var text_width: c_int = undefined;
        var text_height: c_int = undefined;
        _ = sdl.TTF_GetTextSize(label, &text_width, &text_height);
        const text_width_float: f32 = @floatFromInt(text_width);
        const text_height_float: f32 = @floatFromInt(text_height);

        var background_color_split = std.mem.splitSequence(u8, background_color, ",");
        _ = sdl.SDL_SetRenderDrawColor(ren, std.fmt.parseInt(u8, background_color_split.next().?, 0) catch 186, std.fmt.parseInt(u8, background_color_split.next().?, 0) catch 85, std.fmt.parseInt(u8, background_color_split.next().?, 0) catch 211, std.fmt.parseInt(u8, background_color_split.next() orelse "255", 0) catch 255);
        _ = sdl.SDL_RenderFillRect(ren, &sdl.SDL_FRect{ .x = starting_x + available_width / 30 + 2, .y = current_y, .w = available_width * 14 / 15 - 4, .h = text_height_float });
        _ = sdl.SDL_RenderFillRect(ren, &sdl.SDL_FRect{ .x = starting_x + available_width / 30 + 1, .y = current_y + 1, .w = available_width * 14 / 15 - 2, .h = text_height_float - 2 });
        _ = sdl.SDL_RenderFillRect(ren, &sdl.SDL_FRect{ .x = starting_x + available_width / 30, .y = current_y + 2, .w = available_width * 14 / 15, .h = text_height_float - 4 });

        var text_color_split = std.mem.splitSequence(u8, text_color, ",");
        _ = sdl.TTF_SetTextColor(label, std.fmt.parseInt(u8, text_color_split.next().?, 0) catch 186, std.fmt.parseInt(u8, text_color_split.next().?, 0) catch 85, std.fmt.parseInt(u8, text_color_split.next().?, 0) catch 211, std.fmt.parseInt(u8, text_color_split.next() orelse "255", 0) catch 255);
        _ = sdl.TTF_DrawRendererText(label, starting_x + available_width / 2 - text_width_float / 2, current_y);

        current_y += text_height_float + 2;
    }

    return current_y - starting_y;
}

fn isMouseWithinRect(mouse_x: f32, mouse_y: f32, rect: sdl.SDL_FRect) bool {
    return !((mouse_x < rect.x) or (mouse_x > rect.x + rect.w) or (mouse_y < rect.y) or (mouse_y > rect.y + rect.h));
}
