const std = @import("std");
const math = std.math;
const settings = @import("settings.zig");
const astronomy = @import("astronomy.zig");

pub const Date: type = struct {
    year: i32 = 0,
    month: i8 = 0,
    day: f64 = 0,
    calendar: CalendarType = .Gregorian,

    pub fn init(year: i32, month: i8, day: f64, calendar: CalendarType) Date {
        return Date{ .year = year, .month = month, .day = day, .calendar = calendar };
    }
    pub fn parse(calendar: CalendarType, string: []const u8) !Date {
        const strLower = try std.ascii.allocLowerString(settings.allocator, string);
        defer settings.allocator.free(strLower);
        var split = std.mem.splitSequence(u8, strLower, " ");

        const split0 = split.next().?;
        var dayString = std.mem.splitSequence(u8, split0, "/");
        const dayString0 = dayString.next().?;
        const dayString1 = dayString.next().?;
        var day = try std.fmt.parseFloat(f64, if (settings.useMonthDayFormatInGregorian) dayString1 else dayString0);
        const month = try std.fmt.parseInt(i8, if (settings.useMonthDayFormatInGregorian) dayString0 else dayString1, 10);

        var hourDigits: []const u8 = undefined;
        var hourLetters: []const u8 = undefined;
        const split1 = split.next() orelse "0";
        const split2 = split.next() orelse "";
        if (!std.ascii.isDigit(split1[split1.len - 1])) {
            var index: usize = 0;
            for (split1, 1..) |char, i| {
                if (!std.ascii.isDigit(char)) {
                    index = i - 1;
                    break;
                }
            }
            hourDigits = split1[0..index];
            hourLetters = split1[index..];
        } else {
            hourDigits = split1;
            hourLetters = split2;
        }
        var time = std.mem.splitSequence(u8, hourDigits, ";");
        day += (try std.fmt.parseFloat(f64, time.next().?)) / 24 + (try std.fmt.parseFloat(f64, time.next() orelse "0")) / 1440 + (try std.fmt.parseFloat(f64, time.next() orelse "0")) / 86400;
        var isNight = false;
        for ([5][]const u8{ "night", "nyx", "pm", "νύξ", "ΝΎΞ" }) |night| {
            if (std.mem.eql(u8, hourLetters, night)) {
                isNight = true;
                break;
            }
        }
        if (isNight and (day - math.floor(day)) <= 0.5) {
            day += 0.5;
        }

        if (calendar == .Attic) { // 1/1/O1Y1 1.8   1/1/1 1.8   1/1/O1Y1 2:30
            var year: i32 = 0;
            if (dayString.next()) |yearString| { // dayString[2]
                if (yearString[0] == 'o') {
                    var olympiadYearSplit = std.mem.splitSequence(u8, yearString[1..], "y");
                    year = 4 * (try std.fmt.parseInt(i32, olympiadYearSplit.next().?, 10)) + (try std.fmt.parseInt(i32, olympiadYearSplit.next().?, 10)) - 1;
                } else {
                    year = try std.fmt.parseInt(i32, yearString, 10);
                }
            } else {
                year = (try JDToDate(.Attic, now(), true, false)).year;
            }

            return Date.init(year, month, day, .Attic);
        } else { // .Gregorian
            var year: i32 = 0;
            if (dayString.next()) |yearString| { // dayString[2]
                year = try std.fmt.parseInt(i32, yearString, 10);
            } else {
                year = (try JDToDate(.Gregorian, now(), true, false)).year;
            }
            return Date.init(year, month, day, .Gregorian);
        }
    }
    pub fn format(self: Date, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        const showDate = std.mem.containsAtLeast(u8, fmt, 1, "d");
        const showTime = std.mem.containsAtLeast(u8, fmt, 1, "t");
        const precision = options.width orelse 0;
        const dayT = math.trunc(self.day);

        if (showDate) {
            if (self.calendar == .Attic) {
                const olympiad = @divFloor(self.year, 4);
                const year = self.year - (olympiad * 4) + 1;

                try writer.print("{d}/{d}/O{d}Y{d}", .{ dayT, self.month, olympiad, year });
            } else {
                if (settings.useMonthDayFormatInGregorian) try writer.print("{d}/{d}/{d}", .{ self.month, dayT, self.year }) else try writer.print("{d}/{d}/{d}", .{ dayT, self.month, self.year });
            }
        }

        if (showDate and showTime) try writer.print(" ", .{});

        if (showTime) {
            const hours = (self.day - dayT) * 24;
            var hoursT = math.trunc(hours);
            const minutes = (hours - hoursT) * 60;

            var amPmString: []const u8 = "";
            if (self.calendar == .Gregorian and settings.use12HourFormatInGregorian) {
                if (hoursT >= 12) {
                    hoursT -= 12;
                    amPmString = "PM";
                } else {
                    amPmString = "AM";
                }
            }

            if (precision == 0) {
                const minutesR = math.round(minutes);
                try writer.print("{d:0>2}:{d:0>2}{s}", .{ hoursT, minutesR, amPmString });
            } else if (precision == 1) {
                const minutesT = math.trunc(minutes);
                const seconds = (minutes - minutesT) * 60;
                try writer.print("{d:0>2}:{d:0>2}:{d:0>2}{s}", .{ hoursT, minutesT, seconds, amPmString });
            }
        }
    }

    pub fn isGregorianYearLeap(year: i32) bool {
        return if (year > 1582) (@rem(year, 4) == 0 and (@rem(year, 100) != 0 or @rem(year, 400) == 0)) else (@rem(year, 4) == 0);
    }
    pub fn getGregorianMonthDayCount(year: i32, month: i8) !u8 {
        if (month == 2) {
            return if (isGregorianYearLeap(year)) 29 else 28;
        } else {
            return switch (month) {
                1 => 31,
                3 => 31,
                4 => 30,
                5 => 31,
                6 => 30,
                7 => 31,
                8 => 31,
                9 => 30,
                10 => 31,
                11 => 30,
                12 => 31,
                else => return error.InvalidMonth,
            };
        }
    }
    pub fn normaliseGregorian(self: Date) void {
        if (self.day < 0) { // Earlier month

        } else {
            var dayCount = getGregorianMonthDayCount(self.year, self.month);
            while (dayCount > self.day) { // Later month
                self.day -= dayCount;
                self.month += 1;
                // self.normaliseMonth();
                dayCount = getGregorianMonthDayCount(self.year, self.month);
            }
        }
    }
    // fn normaliseMonth(self: Date) void {}
    // TODO
};
pub const CalendarType: type = enum { Gregorian, Attic };
pub const CalendarTypeSetting: type = enum { primary, secondary, anniversary, Gregorian, Attic };
pub fn convertCalendarTypeSetting(calendarTypeSettingIn: u8) CalendarType {
    if (calendarTypeSettingIn < 3) {
        switch (calendarTypeSettingIn) {
            0 => return settings.primaryCalendar,
            1 => return settings.secondaryCalendar,
            else => return if (settings.anniversaryCalendarConfirmed) settings.primaryCalendar else settings.secondaryCalendar,
        }
    } else {
        return @enumFromInt(calendarTypeSettingIn - 3);
    }
}

pub const DateInfo: type = struct {
    mainDate: Date,
    firstOfTheYearJD: f64,
    firstOfTheMonthJD: f64,
    monthsInYear: i8,
    daysInMonth: u8,
    rowSize: u8,
    minRows: u8,

    pub fn init(mainDate: Date, firstOfTheYearJD: f64, firstOfTheMonthJD: f64, monthsInYear: i8, daysInMonth: u8, rowSize: u8, minRows: u8) DateInfo {
        return DateInfo{ .mainDate = mainDate, .firstOfTheYearJD = firstOfTheYearJD, .firstOfTheMonthJD = firstOfTheMonthJD, .monthsInYear = monthsInYear, .daysInMonth = daysInMonth, .rowSize = rowSize, .minRows = minRows };
    }
    pub fn format(self: DateInfo, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("date: {dt}, firstOfTheYearJD: {d}, firstOfTheMonthJD: {d}, monthsInYear: {d}, daysInMonth: {d}, rowSize: {d}, minRows: {d}", .{ self.mainDate, self.firstOfTheYearJD, self.firstOfTheMonthJD, self.monthsInYear, self.daysInMonth, self.rowSize, self.minRows });
    }
};
// properDate means whether in calendars starting days at different times than the Gregorian the time of day should be counted for the date, doesn't matter when includeTimeOfDay is true
// properDate and includeTimeOfDay do use more resources for some calendars, so they should not be used when it's not necessary
pub fn getDateInfo(calendar: CalendarType, JD: f64, properDate: bool, includeTimeOfDay: bool) !DateInfo {
    var outputDate: Date = undefined;
    var firstOfTheYearJD: f64 = 0;
    var firstOfTheMonthJD: f64 = 0;
    var monthsInYear: i8 = 12;
    var daysInMonth: u8 = 30;
    var rowSize: u8 = 7;
    var minRows: u8 = 5;

    if (calendar == .Gregorian) {
        const gregorianDate = JDToGregorian(JD);
        if (includeTimeOfDay) outputDate = gregorianDate else outputDate = Date.init(gregorianDate.year, gregorianDate.month, math.floor(gregorianDate.day), .Gregorian);

        firstOfTheYearJD = try gregorianToJD(Date.init(gregorianDate.year, 1, 1, .Gregorian));
        firstOfTheMonthJD = try gregorianToJD(Date.init(gregorianDate.year, gregorianDate.month, 1, .Gregorian));

        monthsInYear = 12;
        daysInMonth = try Date.getGregorianMonthDayCount(gregorianDate.year, gregorianDate.month);

        rowSize = 7;
        minRows = 5;
    } else if (calendar == .Attic) {
        var JDvar = JD;
        if (!properDate and !includeTimeOfDay) JDvar += 0.5; // if (!properDate && !includeTimeOfDay) date = date.AddHours(12);
        // if (date == RoundDateTime(date, CalendarType.Gregorian)) date = date.AddMilliseconds(1); // TODO

        const spb = try astronomy.getClosestSunPhase(JDvar, false, 1);
        var year: i32 = spb.year;
        firstOfTheYearJD = roundDate(spb.JD, .Attic);
        const mpf = try astronomy.getClosestMoonPhase(firstOfTheYearJD, true, 0);
        var k: f32 = mpf.k;
        firstOfTheYearJD = ceilingDate(mpf.JD, .Attic);

        var nextFirstOfTheYearBasedOnSolstice = roundDate(try astronomy.getDateForSunPhase(year + 1, 1), .Attic);

        if (firstOfTheYearJD > floorDate(JDvar, .Attic)) // For when date is after solstice, but before first new moon of the year
        {
            nextFirstOfTheYearBasedOnSolstice = roundDate(spb.JD, .Attic);
            year -= 1;
            firstOfTheYearJD = roundDate(try astronomy.getDateForSunPhase(year, 1), .Attic);
            const mpf1 = try astronomy.getClosestMoonPhase(firstOfTheYearJD, true, 0);
            k = mpf1.k;
            firstOfTheYearJD = ceilingDate(mpf1.JD, .Attic);
        }

        var moonI: u8 = 0;
        var newMoon = firstOfTheYearJD;
        var monthBeginnings: [13]f64 = .{ -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 };
        while (newMoon <= nextFirstOfTheYearBasedOnSolstice) {
            monthBeginnings[moonI] = newMoon;
            k += 1;
            newMoon = ceilingDate(try astronomy.getDateForMoonPhase(k), .Attic);
            moonI += 1;
        }
        monthsInYear = @intCast(moonI);
        const firstOfTheNextYear = ceilingDate(try astronomy.getDateForMoonPhase(k), .Attic);

        var month: u8 = 0;
        for (monthBeginnings, 0..) |element, i| {
            // firstOfTheMonthJD = monthBeginnings.Where(element => element <= date).Max();
            if (element != -1 and element <= JDvar) {
                if (element > firstOfTheMonthJD) {
                    firstOfTheMonthJD = element;
                    month = @intCast(i + 1); // +1 because of lists starting at 0
                }
            }
        }

        year += 779;
        const dayUnrounded = JDvar - firstOfTheMonthJD;
        var day = math.ceil(dayUnrounded);

        if (properDate or includeTimeOfDay) {
            const dayFraction = dayUnrounded - math.floor(dayUnrounded);
            const utcOffset = 0;
            const sunrise = astronomy.getTimeOfSunTransitRiseSet(JDvar, utcOffset, false, true, false)[1];

            if (!includeTimeOfDay) {
                if (dayFraction < sunrise) // Before sunrise
                {
                    day -= 1;
                }
            } else {
                const sunset = astronomy.getTimeOfSunTransitRiseSet(JDvar, utcOffset, false, false, true)[2];
                if (dayFraction < sunrise) // Before sunrise
                {
                    const prevDaySunset = astronomy.getTimeOfSunTransitRiseSet(JDvar - 1, utcOffset, false, false, true)[2];
                    const segmentLength = (sunrise - prevDaySunset) / 12;
                    const hour = (sunrise - dayFraction) / segmentLength;
                    day += hour / 24;
                } else if (dayFraction > sunset) // After sunset
                {
                    const nextDaySunrise = astronomy.getTimeOfSunTransitRiseSet(JDvar + 1, utcOffset, false, true, false)[1];
                    const segmentLength = (nextDaySunrise - sunset) / 12;
                    const hour = (nextDaySunrise - dayFraction) / segmentLength;
                    day += hour / 24;
                } else // Mid day
                {
                    const segmentLength = (sunset - sunrise) / 12;
                    const hour = (dayFraction - sunrise) / segmentLength;
                    day += hour / 24;
                }
            }

            if (day < 1) {
                var newDateInfo = try getDateInfo(.Attic, JDvar - 0.5, properDate, includeTimeOfDay);
                newDateInfo.mainDate.day += 0.5;
                // newDateInfo.mainDate = newDateInfo.mainDate.normaliseGregorian();
                return newDateInfo;
            } // TODO: Make sure this works
        }

        // if (@abs(math.round(day) - day) < 0.001) day = math.round(day); // TODO
        outputDate = Date.init(year, @intCast(month), day, .Attic);

        var firstOfTheNextMonth: f64 = 0;
        if (moonI > month) {
            firstOfTheNextMonth = ceilingDate(monthBeginnings[month], .Attic);
        } else {
            firstOfTheNextMonth = ceilingDate(firstOfTheNextYear, .Attic);
        }
        daysInMonth = @intFromFloat(math.round(firstOfTheNextMonth - firstOfTheMonthJD));

        rowSize = 5;
        minRows = 6;
    }

    return DateInfo.init(outputDate, firstOfTheYearJD, firstOfTheMonthJD, monthsInYear, daysInMonth, rowSize, minRows);
}

// These are really weird, but they work, they don't round till the beginning of the day in the chosen calendar, just substract whenever the day starts and round according to gregorian rules, so you don't get the beginning of the day here, but you can use it to check whether two dates are in the same day as well as to assign a gregorian date to a date of another calendar
pub fn ceilingDate(JD: f64, calendar: CalendarType) f64 {
    var JDvar = JD;
    if (calendar == .Attic) {
        const utcOffset = 0;
        JDvar -= astronomy.getTimeOfSunTransitRiseSet(JD, utcOffset, false, true, false)[1];
    }

    JDvar -= 0.5;
    JDvar = if (JDvar != math.floor(JDvar)) math.floor(JDvar) + 1 else math.floor(JDvar);
    JDvar += 0.5;
    return JDvar;
}
pub fn floorDate(JD: f64, calendar: CalendarType) f64 {
    var JDvar = JD;
    if (calendar == .Attic) {
        const utcOffset = 0;
        JDvar -= astronomy.getTimeOfSunTransitRiseSet(JD, utcOffset, false, true, false)[1];
    }

    JDvar -= 0.5;
    JDvar = math.floor(JDvar);
    JDvar += 0.5;
    return JDvar;
}
pub fn roundDate(JD: f64, calendar: CalendarType) f64 {
    var JDvar = JD;
    if (calendar == .Attic) {
        const utcOffset = 0;
        JDvar -= astronomy.getTimeOfSunTransitRiseSet(JD, utcOffset, false, true, false)[1];
    }

    JDvar -= 0.5;
    JDvar = if (JDvar - math.floor(JDvar) >= 0.5) math.floor(JDvar) + 1 else math.floor(JDvar);
    JDvar += 0.5;
    return JDvar;
}

// See getDateInfo() for notes, including properDate meaning
pub fn dateToJD(date: Date, properDate: bool, includeTimeOfDay: bool) !f64 {
    if (date.calendar == .Attic) {
        var JD = 1721423.5 + (@as(f64, @floatFromInt(date.year)) - 779) * 365.2425 + (@as(f64, @floatFromInt(date.month)) - 6) * 30.44; // Guestimation
        std.debug.print("JDa: {d}\n", .{JD});
        var dateInfo = try getDateInfo(.Attic, JD, false, false);

        while (dateInfo.mainDate.year != date.year) {
            JD += if (dateInfo.mainDate.year < date.year) 362 else -362;
            dateInfo = try getDateInfo(.Attic, JD, false, false);
        }
        while (dateInfo.mainDate.month != date.month) {
            JD += if (dateInfo.mainDate.month < date.month) 28 else -28;
            dateInfo = try getDateInfo(.Attic, JD, false, false);
        }
        JD += date.day - dateInfo.mainDate.day;
        JD = floorDate(JD, .Gregorian);
        std.debug.print("JDas: {d}\n", .{JD});

        if (includeTimeOfDay or properDate) {
            var midnightInAttic = (try getDateInfo(.Attic, JD, true, true)).mainDate.day;
            if (math.floor(midnightInAttic) < math.floor(date.day)) midnightInAttic = (try getDateInfo(.Attic, JD + 1, true, true)).mainDate.day;

            if (includeTimeOfDay) {
                const midnightHour = (midnightInAttic - math.floor(midnightInAttic)) * 24;
                const hour = (date.day - math.floor(date.day)) * 24; // In attic

                JD += 1;
                const utcOffset = 0;
                const sunRiseSet = astronomy.getTimeOfSunTransitRiseSet(JD, utcOffset, false, true, true);

                if (hour >= 12 and hour >= midnightHour) // Before sunrise
                {
                    const prevDaySunset = astronomy.getTimeOfSunTransitRiseSet(JD - 1, utcOffset, false, false, true)[2];
                    const segmentLength = (sunRiseSet[1] - prevDaySunset) / 12; // length of attic hour in gregorian hours
                    const dayFraction = (hour - midnightHour) * @abs(segmentLength); // fraction in gregorian
                    JD += dayFraction;
                } else if (hour >= 12 and hour < midnightHour) // After sunset //gud
                {
                    const nextDaySunrise = astronomy.getTimeOfSunTransitRiseSet(JD + 1, utcOffset, false, true, false)[1];
                    const segmentLength = (nextDaySunrise - sunRiseSet[2]) / 12;
                    const dayFraction = (hour - midnightHour) * @abs(segmentLength);
                    JD += dayFraction;
                } else // Mid day //gud
                {
                    const segmentLength = (sunRiseSet[2] - sunRiseSet[1]) / 12;
                    const dayFraction = hour * segmentLength + sunRiseSet[1];
                    JD += dayFraction - 1;
                }
            } else {
                if (date.day > midnightInAttic) JD += 1;
            }
        }
        return JD;
    } else {
        return try gregorianToJD(date);
    }
}
// See getDateInfo() for notes, including properDate meaning
pub fn JDToDate(calendar: CalendarType, JD: f64, properDate: bool, includeTimeOfDay: bool) !Date {
    if (calendar == .Attic) {
        return (try getDateInfo(.Attic, JD, properDate, includeTimeOfDay)).mainDate;
    } else {
        return JDToGregorian(JD);
    }
}

pub fn JDToGregorian(JD: f64) Date {
    // Chapter 7, pdf page 71

    const JD05 = JD + 0.5;
    const Z = math.trunc(JD05);
    const F = JD05 - Z;
    var A = Z;
    if (Z >= 2299161) { // or 2291161??
        const alpha = math.trunc((Z - 1867216.25) / 36524.25);
        A = Z + 1 + alpha - math.trunc(alpha / 4);
    }
    const B = A + 1524;
    const C = math.trunc((B - 122.1) / 365.25);
    const D = math.trunc(365.25 * C);
    const E = math.trunc((B - D) / 30.6001);
    const day = B - D - math.trunc(30.6001 * E) + F;
    var month: i8 = 0;
    if (E >= 14) {
        month = @intFromFloat(E - 13);
    } else {
        month = @intFromFloat(E - 1);
    }
    var year: i32 = 0;
    if (month <= 2) {
        year = @intFromFloat(C - 4715);
    } else {
        year = @intFromFloat(C - 4716);
    }
    return Date.init(year, month, day, .Gregorian);
}
pub fn gregorianToJD(date: Date) !f64 {
    if (date.calendar != .Gregorian) return error.WrongCalendar;
    var year = date.year;
    var month = date.month;
    const day = date.day;
    // Chapter 7, pdf page 69

    if (month <= 2) {
        year -= 1;
        month += 12;
    }
    const A = @divTrunc(year, 100);
    var B: i32 = 0;
    if (year >= 1582) { // when Gregorian was created
        if (year > 1582 or month >= 10) {
            if (year > 1582 or month > 10 or day >= 15.5) {
                B = 2 - A + @divTrunc(A, 4);
            }
        }
    }
    return math.trunc(365.25 * @as(f64, @floatFromInt(year + 4716))) + math.trunc(30.6001 * @as(f64, @floatFromInt(month + 1))) + day + @as(f64, @floatFromInt(B)) - 1524.5;
}

pub fn now() f64 {
    var JD: f64 = 2440587.5; // Epoch 01/01/1970
    JD += @as(f64, @floatFromInt(std.time.timestamp())) / 86400;
    return JD;
}
