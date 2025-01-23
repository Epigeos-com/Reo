const std = @import("std");
const dates = @import("dates.zig");
const astronomy = @import("astronomy.zig");
const settings = @import("settings.zig");
pub fn addEvent(isComplex: bool, JDstart: f64, JDend: f64, category: []const u8, calendar: dates.CalendarType, repeatsCalendar: dates.CalendarTypeSetting, repeats: []const u8, title: []const u8, backgroundColor: []const u8, textColor: []const u8) !void {
    const repeatsNew = try std.ascii.allocLowerString(settings.allocator, repeats);
    // all string inputs should use replace ';' with ';' (the second one is a Greek question mark) to avoid input semicolons to be counted as end of argument
    const titleNew = try std.mem.replaceOwned(u8, settings.allocator, title, ";", ";");
    const backgroundColorNew = try std.mem.replaceOwned(u8, settings.allocator, backgroundColor, ";", ";");
    const textColorNew = try std.mem.replaceOwned(u8, settings.allocator, textColor, ";", ";");
    const evString = try std.fmt.allocPrint(settings.allocator, "{d};{d};{s};{d};{d};{s};{s};{s};{s}\n", .{ JDstart, JDend, category, @intFromEnum(calendar), @intFromEnum(repeatsCalendar), repeatsNew, titleNew, backgroundColorNew, textColorNew });
    defer settings.allocator.free(evString);
    settings.allocator.free(repeatsNew);
    settings.allocator.free(titleNew);
    settings.allocator.free(backgroundColorNew);
    settings.allocator.free(textColorNew);

    if (!isComplex) {
        try settings.appendFile(settings.envDir, "events.data", evString);
    } else {
        try settings.appendFile(settings.envDir, "complexEvents.data", evString);
        const now = dates.now();
        try presaveComplexEvents(now - settings.presaveComplexEventsForDays, now + settings.presaveComplexEventsForDays);
    }
}
pub fn removeEvent(isComplex: bool, ev: []const u8) !void {
    const file = try settings.envDir.openFile(if (isComplex) "complexEvents.data" else "events.data", .{ .mode = .read_write });
    defer file.close();

    const reader = file.reader();

    var iOfMatch: usize = 0;
    var i: usize = 0;
    const evWithNewlines = try std.mem.join(settings.allocator, "", &[3][]const u8{ "\n", ev, "\n" });
    while (true) {
        const byte = reader.readByte() catch return error.EventNotThere;
        if (byte == evWithNewlines[iOfMatch]) {
            iOfMatch += 1;
            if (iOfMatch == evWithNewlines.len) break;
        } else {
            iOfMatch = 0;
        }
        i += 1;
    }

    const endPos = try file.getEndPos();
    const fileTemp = try settings.envDir.createFile("ev.temp", .{ .read = true });
    try fileTemp.writeAll("\n");
    _ = try file.copyRange(i + 1, fileTemp, 1, endPos - i - 1);
    _ = try fileTemp.copyRange(0, file, i - evWithNewlines.len + 1, endPos - i);
    try file.setEndPos(endPos - evWithNewlines.len + 1);
    fileTemp.close();
    try settings.envDir.deleteFile("ev.temp");

    if (isComplex) {
        const now = dates.now();
        try presaveComplexEvents(now - settings.presaveComplexEventsForDays, now + settings.presaveComplexEventsForDays);
    }
}

// Viable i.e. by time range, not being a comment and category, needs to be manually freed
pub fn getViableEventsForDates(allocator: std.mem.Allocator, JDstart: f64, JDend: f64, fileName: []const u8) ![][]const u8 {
    const file = try settings.envDir.openFile(fileName, .{});
    defer file.close();
    const reader = file.reader();

    var viableEvents = std.ArrayList([]const u8).init(allocator);
    defer viableEvents.deinit();

    while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 50000)) |line| {
        if (validateEvent(line, JDstart, JDend)) try viableEvents.append(line);
    }

    return try viableEvents.toOwnedSlice();
}
fn validateEvent(ev: []const u8, JDstart: f64, JDend: f64) bool {
    if (std.mem.startsWith(u8, ev, "//")) return false;

    var l = std.mem.splitSequence(u8, ev, ";");

    const l0 = l.next() orelse return false;
    const l1 = l.next() orelse return false;
    const l2 = l.next() orelse return false; // this argument is optional, but then it's "", not empty

    if (l2.len != 0) {
        for (settings.disabledEventCategories) |disabledCategory| {
            if (std.mem.eql(u8, disabledCategory, l2)) return false;
        }
    }

    if (std.mem.eql(u8, l0, "-1")) {
        const evStartingDate = dates.floorDate(std.fmt.parseFloat(f64, l0) catch return false, settings.primaryCalendar);
        if (std.math.floor(evStartingDate) > std.math.floor(JDend)) return false;
    }

    if (std.mem.eql(u8, l1, "-1")) return true;
    const evEndingDate = dates.floorDate(std.fmt.parseFloat(f64, l1) catch return false, settings.primaryCalendar);
    return std.math.floor(evEndingDate) >= std.math.floor(JDstart);
}
// Needs to be manually freed
pub fn getEventsForDate(allocator: std.mem.Allocator, JD: f64) ![][]const u8 {
    const simpleEvents = try getViableEventsForDates(settings.allocator, JD, JD, "events.data");
    const complexEvents = try getViableEventsForDates(settings.allocator, JD, JD, "complexEvents.simplified.data");
    const events = try std.mem.concat(settings.allocator, []const u8, &[2][][]const u8{ simpleEvents, complexEvents });
    settings.allocator.free(simpleEvents);
    settings.allocator.free(complexEvents);
    defer settings.allocator.free(events);

    var relevantEvents = std.ArrayList([]const u8).init(allocator);
    defer relevantEvents.deinit();
    for (events) |ev| {
        var arguments = std.mem.splitSequence(u8, ev, ";");
        const arg0 = arguments.next().?;
        _ = arguments.next();
        _ = arguments.next();
        _ = arguments.next();
        const arg4 = arguments.next().?;
        const arg5 = arguments.next().?;

        var isRepeatTrue = true;
        if (arg5.len != 0) {
            const repeatsCalendar = dates.convertCalendarTypeSetting(try std.fmt.parseInt(u8, arg4, 10));
            const date = try dates.JDToDate(repeatsCalendar, JD, true, false);

            var repeatSubformulae = std.mem.splitSequence(u8, arg5, "&");
            while (repeatSubformulae.next()) |repeatSubformula| {
                var conditionArgs = std.mem.splitSequence(u8, repeatSubformula, "-");
                const condArg0 = conditionArgs.next() orelse {
                    isRepeatTrue = false;
                    break;
                };
                const condArg1 = conditionArgs.next() orelse {
                    isRepeatTrue = false;
                    break;
                };
                const condArg2 = conditionArgs.next() orelse {
                    isRepeatTrue = false;
                    break;
                };
                const condArg3 = conditionArgs.next() orelse "";

                if (std.mem.eql(u8, condArg0, "where")) {
                    const value = if (std.mem.eql(u8, condArg1, "month")) date.month else @as(i8, @intFromFloat(std.math.floor(date.day)));
                    if (value != try std.fmt.parseInt(i8, condArg2, 10)) {
                        isRepeatTrue = false;
                        break;
                    }
                } else // every
                {
                    const gregorianFirstDate = try std.fmt.parseFloat(f64, arg0);

                    const targetResult = std.fmt.parseInt(i32, condArg3, 10) catch 0;

                    var meetsCondition = false;
                    if (std.mem.eql(u8, condArg1, "day")) {
                        meetsCondition = @rem(@as(i32, @intFromFloat(std.math.floor(JD - gregorianFirstDate))), try std.fmt.parseInt(i32, condArg2, 10)) == targetResult;
                    } else // year
                    {
                        const firstDate = try dates.JDToDate(repeatsCalendar, gregorianFirstDate, true, false);
                        if (date.day == firstDate.day and date.month == firstDate.month) meetsCondition = @rem((date.year - firstDate.year), try std.fmt.parseInt(i32, condArg2, 10)) == targetResult;
                    }

                    if (!meetsCondition) {
                        isRepeatTrue = false;
                        break;
                    }
                }
            }
        }
        if (isRepeatTrue) try relevantEvents.append(ev);
    }

    return try relevantEvents.toOwnedSlice();
}

pub fn presaveComplexEvents(JDstart: f64, JDend: f64) !void {
    const complexEvents = try getViableEventsForDates(settings.allocator, JDstart, JDend, "complexEvents.data");
    defer settings.allocator.free(complexEvents);
    var simplifiedEvents = std.ArrayList(u8).init(settings.allocator);
    defer simplifiedEvents.deinit();

    for (complexEvents) |ev| {
        var arguments = std.mem.splitSequence(u8, ev, ";");
        _ = arguments.next();
        _ = arguments.next();
        const category = arguments.next().?;
        const calendar = arguments.next().?;
        const repeatsCalendar = arguments.next().?;
        const repeats = arguments.next().?;
        const title = arguments.next().?;
        const backgroundColor = arguments.next().?;
        const textColor = arguments.next().?;

        const results = try evaluateComplexExpression(settings.allocator, repeats, dates.convertCalendarTypeSetting(try std.fmt.parseInt(u8, repeatsCalendar, 10)), JDstart, JDend);
        for (results) |result| {
            const newEventString = try std.fmt.allocPrint(settings.allocator, "{d};{d};{s};{s};{s};{s};{s};{s};{s}\n", .{ result, result, category, calendar, repeatsCalendar, repeats, title, backgroundColor, textColor });
            try simplifiedEvents.appendSlice(newEventString);
            settings.allocator.free(newEventString);
        }
        settings.allocator.free(results);
    }
    try settings.envDir.writeFile(.{ .sub_path = "complexEvents.simplified.data", .data = simplifiedEvents.items });
}
// Must be freed manually
pub fn evaluateComplexExpression(allocator: std.mem.Allocator, expression: []const u8, calendar: dates.CalendarType, JDstart: f64, JDend: f64) ![]const f64 {
    var fittingDates = std.ArrayList(f64).init(allocator);
    defer fittingDates.deinit();
    var i: f64 = JDstart;
    while (i < JDend) {
        const date = try evaluateComplexExpressionForDate(i, expression, calendar);
        try fittingDates.append(date);

        i += 28;
    }
    return try fittingDates.toOwnedSlice();
}
fn evaluateComplexExpressionForDate(JD: f64, expression: []const u8, calendar: dates.CalendarType) !f64 {
    var segments = std.mem.splitSequence(u8, expression, "/");

    var referenceDate = JD;
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
            referenceDate = std.fmt.parseFloat(f64, arg0) catch try evaluateFunction(arg0, arg1, referenceDate, action, calendar);
        }
    }
    return referenceDate;
}
fn evaluateFunction(arg0: []const u8, arg1: []const u8, referenceDate: f64, action: u8, calendar: dates.CalendarType) !f64 {
    _ = calendar;
    if (action == 0) {
        if (std.mem.eql(u8, arg0, "moon")) {
            return (try astronomy.getClosestMoonPhase(referenceDate, true, try std.fmt.parseInt(u8, arg1, 10))).JD;
        } else {
            return (try astronomy.getClosestSunPhase(referenceDate, true, try std.fmt.parseInt(u8, arg1, 10))).JD;
        }
    } else if (action == 1) {
        if (std.mem.eql(u8, arg0, "moon")) {
            return (try astronomy.getClosestMoonPhase(referenceDate, false, try std.fmt.parseInt(u8, arg1, 10))).JD;
        } else {
            return (try astronomy.getClosestSunPhase(referenceDate, false, try std.fmt.parseInt(u8, arg1, 10))).JD;
        }
    } else if (action == 2) {
        if (std.mem.eql(u8, arg0, "moon")) {
            const prev = (try astronomy.getClosestMoonPhase(referenceDate, false, try std.fmt.parseInt(u8, arg1, 10))).JD;
            const next = (try astronomy.getClosestMoonPhase(referenceDate, true, try std.fmt.parseInt(u8, arg1, 10))).JD;
            return if (referenceDate - prev < next - referenceDate) prev else next;
        } else {
            const prev = (try astronomy.getClosestSunPhase(referenceDate, false, try std.fmt.parseInt(u8, arg1, 10))).JD;
            const next = (try astronomy.getClosestSunPhase(referenceDate, true, try std.fmt.parseInt(u8, arg1, 10))).JD;
            return if (referenceDate - prev < next - referenceDate) prev else next;
        }
    }
    return error.InvalidAction;
}
