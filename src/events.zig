const std = @import("std");
const dates = @import("dates.zig");
const astronomy = @import("astronomy.zig");
const manager = @import("manager.zig");
const settings = @import("settings.zig");
pub fn addEvent(is_complex: bool, jd_start: f64, jd_end: f64, category: []const u8, calendar: dates.CalendarType, repeats_calendar: dates.CalendarTypeSetting, repeats: []const u8, title: []const u8, background_color: []const u8, text_color: []const u8) !void {
    const repeats_new = try std.ascii.allocLowerString(manager.allocator, repeats);
    // replace ';' with ';' (the second one is a Greek question mark) to avoid input semicolons to be counted as end of argument
    const title_new = try std.mem.replaceOwned(u8, manager.allocator, title, ";", ";");
    const background_color_new = try std.mem.replaceOwned(u8, manager.allocator, background_color, ";", "");
    const text_color_new = try std.mem.replaceOwned(u8, manager.allocator, text_color, ";", "");
    const ev_string = try std.fmt.allocPrint(manager.allocator, "{d};{d};{s};{d};{d};{s};{s};{s};{s}\n", .{ jd_start, jd_end, category, @intFromEnum(calendar), @intFromEnum(repeats_calendar), repeats_new, title_new, background_color_new, text_color_new });
    defer manager.allocator.free(ev_string);
    manager.allocator.free(repeats_new);
    manager.allocator.free(title_new);
    manager.allocator.free(background_color_new);
    manager.allocator.free(text_color_new);

    if (!is_complex) {
        try manager.appendFile(manager.env_dir, "events.data", ev_string);
    } else {
        try manager.appendFile(manager.env_dir, "complexEvents.data", ev_string);
        const now = dates.now();
        try presaveComplexEvents(now - settings.presave_complex_events_for_days, now + settings.presave_complex_events_for_days);
    }
}
pub fn removeEvent(is_complex: bool, ev: []const u8) !void {
    const file = try manager.env_dir.openFile(if (is_complex) "complexEvents.data" else "events.data", .{ .mode = .read_write });
    defer file.close();

    const reader = file.reader();

    var i_of_match: usize = 0;
    var i: usize = 0;
    const ev_with_newlines = try std.mem.join(manager.allocator, "", &[3][]const u8{ "\n", ev, "\n" });
    while (true) {
        const byte = reader.readByte() catch return error.EventNotThere;
        if (byte == ev_with_newlines[i_of_match]) {
            i_of_match += 1;
            if (i_of_match == ev_with_newlines.len) break;
        } else {
            i_of_match = 0;
        }
        i += 1;
    }

    const end_pos = try file.getEndPos();
    const file_temp = try manager.env_dir.createFile("ev.temp", .{ .read = true });
    try file_temp.writeAll("\n");
    _ = try file.copyRange(i + 1, file_temp, 1, end_pos - i - 1);
    _ = try file_temp.copyRange(0, file, i - ev_with_newlines.len + 1, end_pos - i);
    try file.setEndPos(end_pos - ev_with_newlines.len + 1);
    file_temp.close();
    try manager.env_dir.deleteFile("ev.temp");

    if (is_complex) {
        const now = dates.now();
        try presaveComplexEvents(now - settings.presave_complex_events_for_days, now + settings.presave_complex_events_for_days);
    }
}

// Needs to be manually freed // Viable i.e. by time range, comment and category
pub fn getViableEventsForDates(allocator: std.mem.Allocator, jd_start: f64, jd_end: f64, file_name: []const u8) ![][]const u8 {
    const file = try manager.env_dir.openFile(file_name, .{});
    defer file.close();

    var viable_events = std.ArrayList([]const u8).init(allocator);
    defer viable_events.deinit();

    const file_text = try file.readToEndAlloc(allocator, 16000000000); // TODO: free this
    var split = std.mem.splitAny(u8, file_text, "\n");
    while (split.next()) |line| {
        if (validateEvent(line, jd_start, jd_end)) try viable_events.append(line);
    }

    return try viable_events.toOwnedSlice();
}
// Validate i.e. by time range, comment and category
fn validateEvent(ev: []const u8, jd_start: f64, jd_end: f64) bool {
    if (std.mem.startsWith(u8, ev, "//")) return false;

    var l = std.mem.splitSequence(u8, ev, ";");

    const l0 = l.next() orelse return false;
    const l1 = l.next() orelse return false;
    const l2 = l.next() orelse return false; // this argument is optional, but then it's "", not null

    if (l2.len != 0) {
        for (settings.disabled_event_categories) |disabled_category| {
            if (std.mem.eql(u8, disabled_category, l2)) return false;
        }
    }

    const ev_starting_date = dates.floorDate(std.fmt.parseFloat(f64, l0) catch return false, settings.primary_calendar);
    if (std.math.floor(ev_starting_date) > std.math.floor(jd_end)) return false;

    if (std.mem.eql(u8, l1, "-1")) return true;
    const ev_ending_date = dates.floorDate(std.fmt.parseFloat(f64, l1) catch return false, settings.primary_calendar);
    return std.math.floor(ev_ending_date) >= std.math.floor(jd_start);
}
// Needs to be freed manually // Format: [day_in_range][event_in_day][char]
pub fn getEventsForDatesArray(allocator: std.mem.Allocator, jd_start: f64, jd_end: f64) ![]const []const []const u8 {
    const events_array = try allocator.alloc(std.ArrayList([]const u8), @intFromFloat(jd_end - jd_start + 1));
    const events = try getEventsForDates(manager.allocator, jd_start, jd_end);
    for (0..events_array.len) |i| {
        events_array[i] = @TypeOf(events_array[0]).init(manager.allocator);
    }
    for (events) |event| {
        try events_array[@intFromFloat(event.jd - jd_start)].append(event.ev);
    }
    var events_list = std.ArrayList([]const []const u8).init(manager.allocator);
    for (0..events_array.len) |i| {
        try events_list.insert(i, try events_array[i].toOwnedSlice());
    }
    return events_list.toOwnedSlice();
}
// Needs to be freed manually
pub const DayEventStruct = struct { jd: f64, ev: []const u8 };
pub fn getEventsForDates(allocator: std.mem.Allocator, jd_start: f64, jd_end: f64) ![]DayEventStruct {
    const simple_events = try getViableEventsForDates(manager.allocator, jd_start, jd_end, "events.data");
    const complex_events = try getViableEventsForDates(manager.allocator, jd_start, jd_end, "complexEvents.simplified.data");
    defer manager.allocator.free(simple_events);
    defer manager.allocator.free(complex_events);

    var relevant_events = std.ArrayList(DayEventStruct).init(allocator);
    for (complex_events) |ev| {
        var arguments = std.mem.splitSequence(u8, ev, ";");
        const arg0 = arguments.next().?;

        const jd = try std.fmt.parseFloat(f64, arg0);
        if (jd >= jd_start and jd <= jd_end) try relevant_events.append(.{ .jd = jd, .ev = ev }); // TODO: this is temp
    }
    for (simple_events) |ev| {
        var arguments = std.mem.splitSequence(u8, ev, ";");
        const arg0 = arguments.next().?;
        const arg1 = arguments.next().?;
        _ = arguments.next();
        _ = arguments.next();
        const arg4 = arguments.next().?;
        const arg5 = arguments.next().?;

        const event_jd_start = try std.fmt.parseFloat(f64, arg0);
        const event_jd_end = if (std.mem.eql(u8, arg1, "-1")) std.math.floatMax(f64) else try std.fmt.parseFloat(f64, arg1);
        const first_jd = @max(jd_start, event_jd_start);
        const last_jd = @min(jd_end + 0.99999, event_jd_end); // TODO: Is there no better way to do this than  + 0.99999?
        if (arg5.len == 0) { // Non-repeating
            var jd = first_jd;
            while (jd <= last_jd) {
                try relevant_events.append(.{ .jd = jd, .ev = ev });
                jd += 1;
            }
        } else {
            const repeats_calendar = dates.convertCalendarTypeSetting(try std.fmt.parseInt(u8, arg4, 10));

            var last_string_end_index: usize = 0;
            var relevant_events_for_formula = std.ArrayList(DayEventStruct).init(manager.allocator);
            for (arg5, 0..) |char, i| {
                if (char != '&' and char != '|' and i != arg5.len - 1) continue; // TODO: could this be made to follow proper order of operations?
                const offset_s: usize = if (i == arg5.len - 1 and last_string_end_index != 0) 1 else 0;
                const offset_e: usize = if (i == arg5.len - 1) 1 else 0;
                const repeat_subformula = arg5[(last_string_end_index + offset_s)..(i + offset_e)];

                var condition_args = std.mem.splitSequence(u8, repeat_subformula, "-");
                const cond_arg0 = condition_args.next() orelse break;
                const cond_arg1 = condition_args.next() orelse break;
                const cond_arg2 = condition_args.next() orelse break;
                var relevant_events_for_subformula = std.ArrayList(DayEventStruct).init(manager.allocator);
                if (std.mem.eql(u8, cond_arg0, "where")) {
                    if (std.mem.eql(u8, cond_arg1, "month")) {
                        const month_number = try std.fmt.parseInt(i8, cond_arg2, 10);
                        const first_date = try dates.jdToDate(repeats_calendar, first_jd, true, false);

                        const year = if (first_date.month <= month_number) first_date.year else first_date.year + 1;
                        var matching_first_of_the_month = try dates.dateToJD(dates.Date.init(year, month_number, 1, repeats_calendar), true, false);
                        var j: i32 = 0;
                        while (matching_first_of_the_month <= last_jd) {
                            const days_in_month = (try dates.getDateInfo(repeats_calendar, matching_first_of_the_month, true, false)).days_in_month;
                            var matching_date = matching_first_of_the_month;
                            if (matching_date < first_jd) matching_date = first_jd;
                            while (matching_date < matching_first_of_the_month + @as(f64, @floatFromInt(days_in_month)) and matching_date <= last_jd) {
                                try relevant_events_for_subformula.append(.{ .jd = matching_date, .ev = ev });
                                matching_date += 1;
                            }
                            j += 1;
                            matching_first_of_the_month = try dates.dateToJD(dates.Date.init(year + j, month_number, 1, repeats_calendar), true, false);
                        }
                    } else { // day
                        const day_number = try std.fmt.parseFloat(f64, cond_arg2);
                        const first_date_info = try dates.getDateInfo(repeats_calendar, first_jd, true, false);
                        var current_matching_date_info = first_date_info;

                        var matching_date = first_jd + day_number - first_date_info.main_date.day;
                        if (matching_date < first_jd) {
                            matching_date += @as(f64, @floatFromInt(first_date_info.days_in_month));
                            current_matching_date_info = try dates.getDateInfo(repeats_calendar, matching_date, true, false);
                        }
                        while (matching_date <= last_jd) {
                            try relevant_events_for_subformula.append(.{ .jd = matching_date, .ev = ev });
                            matching_date += @as(f64, @floatFromInt(current_matching_date_info.days_in_month));
                            if (matching_date <= last_jd) current_matching_date_info = try dates.getDateInfo(repeats_calendar, matching_date, true, false);
                        }
                    }
                } else { // every
                    if (std.mem.eql(u8, cond_arg1, "day")) {
                        const day_count = try std.fmt.parseFloat(f64, cond_arg2);
                        var matching_date = first_jd + if (first_jd > event_jd_start) @rem(day_count - @rem(first_jd - event_jd_start, day_count), day_count) else @rem(event_jd_start - first_jd, day_count);
                        while (matching_date <= last_jd) {
                            try relevant_events_for_subformula.append(.{ .jd = matching_date, .ev = ev });
                            matching_date += day_count;
                        }
                    } else { // year // TODO: verify this works
                        const year_count = try std.fmt.parseInt(i32, cond_arg2, 10);
                        const first_date = try dates.jdToDate(repeats_calendar, first_jd, true, false);
                        const end_date = try dates.jdToDate(repeats_calendar, jd_end, true, false);
                        const event_start_date = try dates.jdToDate(repeats_calendar, event_jd_start, true, false);

                        var year = first_date.year + @rem(@as(i32, @intCast(@abs(first_date.year - event_start_date.year))), year_count);
                        if (year <= end_date.year) {
                            var matching_date = try dates.dateToJD(dates.Date.init(year, event_start_date.month, event_start_date.day, repeats_calendar), true, false);
                            if (matching_date >= first_jd) {
                                while (matching_date <= last_jd) {
                                    try relevant_events_for_subformula.append(.{ .jd = matching_date, .ev = ev });
                                    year += year_count;
                                    matching_date = try dates.dateToJD(dates.Date.init(year, event_start_date.month, event_start_date.day, repeats_calendar), true, false);
                                    // TODO: if (end_date.year < year or (end_date.year == year and end_date.month <= event_start_date.month)) matching_date = try dates.dateToJD(dates.Date.init(year, event_start_date.month, event_start_date.day, repeats_calendar), true, true) else break;
                                }
                            }
                        }
                    }
                }

                if (last_string_end_index == 0) {
                    relevant_events_for_formula.deinit();
                    relevant_events_for_formula = relevant_events_for_subformula;
                } else {
                    if (arg5[last_string_end_index] == '&') {
                        var relevant_events_intersect = std.ArrayList(DayEventStruct).init(manager.allocator);
                        for (relevant_events_for_subformula.items) |relevant_event_for_subformula| {
                            for (relevant_events_for_formula.items) |relevant_event_for_formula| {
                                if (std.meta.eql(relevant_event_for_subformula, relevant_event_for_formula)) try relevant_events_intersect.append(relevant_event_for_subformula);
                            }
                        }
                        relevant_events_for_formula.deinit();
                        relevant_events_for_formula = relevant_events_intersect;
                        relevant_events_for_subformula.deinit();
                    } else {
                        const relevant_events_for_subformula_slice = try relevant_events_for_subformula.toOwnedSlice();
                        try relevant_events_for_formula.appendSlice(relevant_events_for_subformula_slice);
                        manager.allocator.free(relevant_events_for_subformula_slice);
                    }
                }
                last_string_end_index = i;
            }

            const relevant_events_for_formula_slice = try relevant_events_for_formula.toOwnedSlice();
            try relevant_events.appendSlice(relevant_events_for_formula_slice);
            manager.allocator.free(relevant_events_for_formula_slice);
        }
    }

    return try relevant_events.toOwnedSlice();
}

pub fn presaveComplexEvents(jd_start: f64, jd_end: f64) !void {
    const complex_events = try getViableEventsForDates(manager.allocator, jd_start, jd_end, "complexEvents.data");
    defer manager.allocator.free(complex_events);
    var simplified_events = std.ArrayList(u8).init(manager.allocator);
    defer simplified_events.deinit();

    for (complex_events) |ev| {
        var arguments = std.mem.splitSequence(u8, ev, ";");
        _ = arguments.next();
        _ = arguments.next();
        const category = arguments.next().?;
        const calendar = arguments.next().?;
        const repeats_calendar = arguments.next().?;
        const repeats = arguments.next().?;
        const title = arguments.next().?;
        const background_color = arguments.next().?;
        const text_color = arguments.next().?;

        const results = try evaluateComplexExpression(manager.allocator, repeats, dates.convertCalendarTypeSetting(try std.fmt.parseInt(u8, repeats_calendar, 10)), jd_start, jd_end);
        for (results) |result| {
            const new_event_string = try std.fmt.allocPrint(manager.allocator, "{d};{d};{s};{s};{s};{s};{s};{s};{s}\n", .{ result, result, category, calendar, repeats_calendar, repeats, title, background_color, text_color });
            try simplified_events.appendSlice(new_event_string);
            manager.allocator.free(new_event_string);
        }
        manager.allocator.free(results);
    }
    try manager.env_dir.writeFile(.{ .sub_path = "complexEvents.simplified.data", .data = simplified_events.items });
}
// Must be freed manually
fn evaluateComplexExpression(allocator: std.mem.Allocator, expression: []const u8, calendar: dates.CalendarType, jd_start: f64, jd_end: f64) ![]const f64 {
    var fitting_dates = std.ArrayList(f64).init(allocator);
    defer fitting_dates.deinit();
    var i: f64 = jd_start;
    while (i < jd_end) {
        const date = try evaluateComplexExpressionForDate(i, expression, calendar);
        try fitting_dates.append(date);

        i += 28;
    }
    return try fitting_dates.toOwnedSlice();
}
fn evaluateComplexExpressionForDate(jd: f64, expression: []const u8, calendar: dates.CalendarType) !f64 {
    var segments = std.mem.splitSequence(u8, expression, "-");

    var reference_date = jd;
    var action: u8 = 0;
    while (segments.next()) |segment| {
        var arguments = std.mem.splitSequence(u8, segment, ":");
        const arg0 = arguments.next().?;
        const arg1 = arguments.next() orelse "";
        if (std.mem.eql(u8, arg0, "next")) {
            action = 0;
        } else if (std.mem.eql(u8, arg0, "previous")) {
            action = 1;
        } else if (std.mem.eql(u8, arg0, "closest")) {
            action = 2;
        } else {
            reference_date = std.fmt.parseFloat(f64, arg0) catch try evaluateFunction(arg0, arg1, reference_date, action, calendar);
        }
    }
    return reference_date;
}
fn evaluateFunction(arg0: []const u8, arg1: []const u8, reference_date: f64, action: u8, calendar: dates.CalendarType) !f64 {
    _ = calendar;
    if (action == 0) {
        if (std.mem.eql(u8, arg0, "moon")) {
            return (try astronomy.getClosestMoonPhase(reference_date, true, try std.fmt.parseInt(u8, arg1, 10))).jd;
        } else {
            return (try astronomy.getClosestSunPhase(reference_date, true, try std.fmt.parseInt(u8, arg1, 10))).jd;
        }
    } else if (action == 1) {
        if (std.mem.eql(u8, arg0, "moon")) {
            return (try astronomy.getClosestMoonPhase(reference_date, false, try std.fmt.parseInt(u8, arg1, 10))).jd;
        } else {
            return (try astronomy.getClosestSunPhase(reference_date, false, try std.fmt.parseInt(u8, arg1, 10))).jd;
        }
    } else if (action == 2) {
        if (std.mem.eql(u8, arg0, "moon")) {
            const prev = (try astronomy.getClosestMoonPhase(reference_date, false, try std.fmt.parseInt(u8, arg1, 10))).jd;
            const next = (try astronomy.getClosestMoonPhase(reference_date, true, try std.fmt.parseInt(u8, arg1, 10))).jd;
            return if (reference_date - prev < next - reference_date) prev else next;
        } else {
            const prev = (try astronomy.getClosestSunPhase(reference_date, false, try std.fmt.parseInt(u8, arg1, 10))).jd;
            const next = (try astronomy.getClosestSunPhase(reference_date, true, try std.fmt.parseInt(u8, arg1, 10))).jd;
            return if (reference_date - prev < next - reference_date) prev else next;
        }
    }
    return error.InvalidAction;
}
