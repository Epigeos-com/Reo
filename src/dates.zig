const std = @import("std");
const math = std.math;
const manager = @import("manager.zig");
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
        const str_lower = try std.ascii.allocLowerString(manager.allocator, string);
        defer manager.allocator.free(str_lower);
        var split = std.mem.splitSequence(u8, str_lower, " ");

        const split0 = split.next().?;
        var day_string = std.mem.splitSequence(u8, split0, "/");
        const day_string0 = day_string.next().?;
        const day_string1 = day_string.next().?;
        var day = try std.fmt.parseFloat(f64, if (settings.use_month_day_format_in_gregorian) day_string1 else day_string0);
        const month = try std.fmt.parseInt(i8, if (settings.use_month_day_format_in_gregorian) day_string0 else day_string1, 10);

        var hour_digits: []const u8 = undefined;
        var hour_letters: []const u8 = undefined;
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
            hour_digits = split1[0..index];
            hour_letters = split1[index..];
        } else {
            hour_digits = split1;
            hour_letters = split2;
        }
        var time = std.mem.splitSequence(u8, hour_digits, ";");
        day += (try std.fmt.parseFloat(f64, time.next().?)) / 24 + (try std.fmt.parseFloat(f64, time.next() orelse "0")) / 1440 + (try std.fmt.parseFloat(f64, time.next() orelse "0")) / 86400;
        var is_night = false;
        for ([5][]const u8{ "night", "nyx", "pm", "νύξ", "ΝΎΞ" }) |night| {
            if (std.mem.eql(u8, hour_letters, night)) {
                is_night = true;
                break;
            }
        }
        if (is_night and (day - math.floor(day)) <= 0.5) {
            day += 0.5;
        }

        if (calendar == .Attic) { // 1/1/O1Y1 1.8   1/1/1 1.8   1/1/O1Y1 2:30
            var year: i32 = 0;
            if (day_string.next()) |year_string| { // dayString[2]
                if (year_string[0] == 'o') {
                    var olympiad_year_split = std.mem.splitSequence(u8, year_string[1..], "y");
                    year = 4 * (try std.fmt.parseInt(i32, olympiad_year_split.next().?, 10)) + (try std.fmt.parseInt(i32, olympiad_year_split.next().?, 10)) - 1;
                } else {
                    year = try std.fmt.parseInt(i32, year_string, 10);
                }
            } else {
                year = (try jdToDate(.Attic, now(), true, false)).year;
            }

            return Date.init(year, month, day, .Attic);
        } else { // .Gregorian
            var year: i32 = 0;
            if (day_string.next()) |year_string| { // dayString[2]
                year = try std.fmt.parseInt(i32, year_string, 10);
            } else {
                year = (try jdToDate(.Gregorian, now(), true, false)).year;
            }
            return Date.init(year, month, day, .Gregorian);
        }
    }
    pub fn format(self: Date, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        const show_date = std.mem.containsAtLeast(u8, fmt, 1, "d");
        const show_month = std.mem.containsAtLeast(u8, fmt, 1, "m");
        const show_time = std.mem.containsAtLeast(u8, fmt, 1, "t");
        const precision = options.width orelse 0;
        const day_t = math.trunc(self.day);

        if (show_date or show_month) {
            if (show_date) {
                if (settings.use_month_day_format_in_gregorian and self.calendar == .Gregorian) try writer.print("{d}/{d}", .{ self.month, day_t }) else try writer.print("{d}/{d}", .{ day_t, self.month });
            } else {
                try writer.print("{d}", .{self.month});
            }

            if (self.calendar == .Attic) {
                const olympiad = @divFloor(self.year, 4);
                const year = self.year - (olympiad * 4) + 1;

                try writer.print("/O{d}Y{d}", .{ olympiad, year });
            } else {
                try writer.print("/{d}", .{self.year});
            }
        }

        if ((show_date or show_month) and show_time) try writer.print(" ", .{});

        if (show_time) {
            const hours = (self.day - day_t) * 24;
            var hours_t = math.trunc(hours);
            const minutes = (hours - hours_t) * 60;

            var am_pm_string: []const u8 = "";
            if (self.calendar == .Gregorian and settings.use_12_hour_format_in_gregorian) {
                if (hours_t >= 12) {
                    hours_t -= 12;
                    am_pm_string = "PM";
                } else {
                    am_pm_string = "AM";
                }
            }

            if (precision == 0) {
                const minutes_r = math.round(minutes);
                try writer.print("{d:0>2}:{d:0>2}{s}", .{ hours_t, minutes_r, am_pm_string });
            } else if (precision == 1) {
                const minutes_t = math.trunc(minutes);
                const seconds = (minutes - minutes_t) * 60;
                try writer.print("{d:0>2}:{d:0>2}:{d:0>2}{s}", .{ hours_t, minutes_t, seconds, am_pm_string });
            }
        }
    }
    // fn normaliseMonth(self: Date) void {}
    // TODO
};
pub const CalendarType: type = enum { Gregorian, Attic };
pub const CalendarTypeSetting: type = enum { primary, secondary, anniversary, Gregorian, Attic };
pub fn convertCalendarTypeSetting(calendar_type_setting_in: u8) CalendarType {
    if (calendar_type_setting_in < 3) {
        switch (calendar_type_setting_in) {
            0 => return settings.primary_calendar,
            1 => return settings.secondary_calendar,
            else => return if (settings.anniversary_calendar) settings.primary_calendar else settings.secondary_calendar,
        }
    } else {
        return @enumFromInt(calendar_type_setting_in - 3);
    }
}

pub const DateInfo: type = struct {
    main_date: Date,
    first_of_the_year_jd: f64,
    first_of_the_month_jd: f64,
    months_in_year: i8,
    days_in_month: u8,
    row_size: u8,
    min_rows: u8,

    pub fn init(main_date: Date, first_of_the_year_jd: f64, first_of_the_month_jd: f64, months_in_year: i8, days_in_month: u8, row_size: u8, min_rows: u8) DateInfo {
        return DateInfo{ .main_date = main_date, .first_of_the_year_jd = first_of_the_year_jd, .first_of_the_month_jd = first_of_the_month_jd, .months_in_year = months_in_year, .days_in_month = days_in_month, .row_size = row_size, .min_rows = min_rows };
    }
    pub fn format(self: DateInfo, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("date: {dt}, first_of_the_year_jd: {d}, first_of_the_month_jd: {d}, months_in_year: {d}, days_in_month: {d}, row_size: {d}, min_rows: {d}", .{ self.main_date, self.first_of_the_year_jd, self.first_of_the_month_jd, self.months_in_year, self.days_in_month, self.row_size, self.min_rows });
    }
};
// proper_date means whether in calendars starting days at different times than the Gregorian the time of day should be counted for the date, doesn't matter when include_time_of_day is true
// proper_date and include_time_of_day do use more resources for some calendars, so they should not be used when it's not necessary
pub fn getDateInfo(calendar: CalendarType, jd: f64, proper_date: bool, include_time_of_day: bool) !DateInfo {
    var output_date: Date = undefined;
    var first_of_the_year_jd: f64 = 0;
    var first_of_the_month_jd: f64 = 0;
    var months_in_year: i8 = 12;
    var days_in_month: u8 = 30;
    var row_size: u8 = 7;
    var min_rows: u8 = 5;

    if (calendar == .Gregorian) {
        const gregorian_date = jdToGregorian(jd);
        if (include_time_of_day) output_date = gregorian_date else output_date = Date.init(gregorian_date.year, gregorian_date.month, math.floor(gregorian_date.day), .Gregorian);

        first_of_the_year_jd = try gregorianToJD(Date.init(gregorian_date.year, 1, 1, .Gregorian));
        first_of_the_month_jd = try gregorianToJD(Date.init(gregorian_date.year, gregorian_date.month, 1, .Gregorian));

        months_in_year = 12;
        days_in_month = try getGregorianMonthDayCount(gregorian_date.year, gregorian_date.month);

        row_size = 7;
        min_rows = 5;
    } else if (calendar == .Attic) {
        if (proper_date) return getDateInfo(calendar, jd, false, false); // TODO
        var jd_var = jd;
        if (!proper_date and !include_time_of_day) jd_var = math.floor(jd - 0.5) + 0.5 + 0.5; // For it to not be a time before sunrise, i.e. the prev day
        // if (date == RoundDateTime(date, CalendarType.Gregorian)) date = date.AddMilliseconds(1); // TODO

        const spb = try astronomy.getClosestSunPhase(jd_var, false, 1);
        var year: i32 = spb.year;
        first_of_the_year_jd = roundDate(spb.jd, .Attic);
        const mpf = try astronomy.getClosestMoonPhase(first_of_the_year_jd, true, 0);
        var k: f32 = mpf.k;
        first_of_the_year_jd = ceilingDate(mpf.jd, .Attic);

        var next_first_of_the_year_based_on_solstice = roundDate(try astronomy.getDateForSunPhase(year + 1, 1), .Attic);

        if (first_of_the_year_jd > floorDate(jd_var, .Attic)) // For when date is after solstice, but before first new moon of the year
        {
            next_first_of_the_year_based_on_solstice = roundDate(spb.jd, .Attic);
            year -= 1;
            first_of_the_year_jd = roundDate(try astronomy.getDateForSunPhase(year, 1), .Attic);
            next_first_of_the_year_based_on_solstice = roundDate(spb.jd, .Attic);
            const mpf1 = try astronomy.getClosestMoonPhase(first_of_the_year_jd, true, 0);
            k = mpf1.k;
            first_of_the_year_jd = ceilingDate(mpf1.jd, .Attic);
        }

        var moon_i: u8 = 0;
        var new_moon = first_of_the_year_jd;
        var month_beginnings: [13]f64 = .{ -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 };
        while (new_moon <= next_first_of_the_year_based_on_solstice) {
            month_beginnings[moon_i] = new_moon;
            k += 1;
            new_moon = ceilingDate(try astronomy.getDateForMoonPhase(k), .Attic);
            moon_i += 1;
        }
        months_in_year = @intCast(moon_i);
        const first_of_the_next_year = ceilingDate(try astronomy.getDateForMoonPhase(k), .Attic);

        var month: u8 = 0;
        for (month_beginnings, 0..) |element, i| {
            // firstOfTheMonthJD = monthBeginnings.Where(element => element <= date).Max();
            if (element != -1 and element <= jd_var) {
                if (element > first_of_the_month_jd) {
                    first_of_the_month_jd = element;
                    month = @intCast(i + 1); // +1 because of lists starting at 0
                }
            }
        }

        year += 779;
        const day_unrounded = jd_var - first_of_the_month_jd;
        var day = math.ceil(day_unrounded);

        if (proper_date or include_time_of_day) {
            const day_fraction = day_unrounded - math.floor(day_unrounded);
            const sunrise = astronomy.getTimeOfSunTransitRiseSet(jd_var, false, true, false)[1];

            if (!include_time_of_day) {
                if (day_fraction < sunrise) // Before sunrise
                {
                    day -= 1;
                }
            } else {
                const sunset = astronomy.getTimeOfSunTransitRiseSet(jd_var, false, false, true)[2];
                if (day_fraction < sunrise) // Before sunrise
                {
                    const prev_day_sunset = astronomy.getTimeOfSunTransitRiseSet(jd_var - 1, false, false, true)[2];
                    const segment_length = (sunrise - prev_day_sunset) / 12;
                    const hour = (sunrise - day_fraction) / segment_length;
                    day += hour / 24;
                } else if (day_fraction > sunset) // After sunset
                {
                    const next_day_sunrise = astronomy.getTimeOfSunTransitRiseSet(jd_var + 1, false, true, false)[1];
                    const segment_length = (next_day_sunrise - sunset) / 12;
                    const hour = (next_day_sunrise - day_fraction) / segment_length;
                    day += hour / 24;
                } else // Mid day
                {
                    const segment_length = (sunset - sunrise) / 12;
                    const hour = (day_fraction - sunrise) / segment_length;
                    day += hour / 24;
                }
            }

            if (day < 1) {
                var new_date_info = try getDateInfo(.Attic, jd_var - 0.5, proper_date, include_time_of_day);
                new_date_info.main_date.day += 0.5;
                // newDateInfo.mainDate = newDateInfo.mainDate.normaliseGregorian();
                return new_date_info;
            } // TODO: Make sure this works
        }

        // if (@abs(math.round(day) - day) < 0.001) day = math.round(day); // TODO
        output_date = Date.init(year, @intCast(month), day, .Attic);

        var first_of_the_next_month: f64 = 0;
        if (moon_i > month) {
            first_of_the_next_month = ceilingDate(month_beginnings[month], .Attic);
        } else {
            first_of_the_next_month = ceilingDate(first_of_the_next_year, .Attic);
        }
        days_in_month = @intFromFloat(math.round(first_of_the_next_month - first_of_the_month_jd));

        row_size = 5;
        min_rows = 6;
    }

    return DateInfo.init(output_date, first_of_the_year_jd, first_of_the_month_jd, months_in_year, days_in_month, row_size, min_rows);
}

// These are really weird, but they work, they don't round till the beginning of the day in the chosen calendar, just substract whenever the day starts and round according to gregorian rules, so you don't get the beginning of the day here, but you can use it to check whether two dates are in the same day as well as to assign a gregorian date to a date of another calendar
pub fn ceilingDate(jd: f64, calendar: CalendarType) f64 {
    var jd_var = jd;
    if (calendar == .Attic) {
        jd_var -= astronomy.getTimeOfSunTransitRiseSet(jd, false, true, false)[1];
    }

    jd_var -= 0.5;
    jd_var = if (jd_var != math.floor(jd_var)) math.floor(jd_var) + 1 else math.floor(jd_var);
    jd_var += 0.5;
    return jd_var;
}
pub fn floorDate(jd: f64, calendar: CalendarType) f64 {
    var jd_var = jd;
    if (calendar == .Attic) {
        jd_var -= astronomy.getTimeOfSunTransitRiseSet(jd, false, true, false)[1];
    }

    jd_var -= 0.5;
    jd_var = math.floor(jd_var);
    jd_var += 0.5;
    return jd_var;
}
pub fn roundDate(jd: f64, calendar: CalendarType) f64 {
    var jd_var = jd;
    if (calendar == .Attic) {
        jd_var -= astronomy.getTimeOfSunTransitRiseSet(jd, false, true, false)[1];
    }

    jd_var -= 0.5;
    jd_var = if (jd_var - math.floor(jd_var) >= 0.5) math.floor(jd_var) + 1 else math.floor(jd_var);
    jd_var += 0.5;
    return jd_var;
}

// See getDateInfo() for notes, including proper_date meaning
pub fn dateToJD(date: Date, proper_date: bool, include_time_of_day: bool) !f64 {
    if (date.calendar == .Attic) {
        if (proper_date) return dateToJD(date, false, false); // TODO
        var jd = 1721423.5 + (@as(f64, @floatFromInt(date.year)) - 779) * 365.2425 + (@as(f64, @floatFromInt(date.month)) - 6) * 30.44; // Guestimation
        var date_info = try getDateInfo(.Attic, jd, false, false);

        while (date_info.main_date.year != date.year) {
            jd += if (date_info.main_date.year < date.year) 352 else -352;
            date_info = try getDateInfo(.Attic, jd, false, false);
        }
        while (date_info.main_date.month != date.month) {
            jd += if (date_info.main_date.month < date.month) 28 else -28;
            date_info = try getDateInfo(.Attic, jd, false, false);
        }
        jd += date.day - date_info.main_date.day;
        jd = floorDate(jd, .Gregorian);

        if (include_time_of_day or proper_date) {
            var midnight_in_attic = (try getDateInfo(.Attic, jd, true, true)).main_date.day;
            if (math.floor(midnight_in_attic) < math.floor(date.day)) midnight_in_attic = (try getDateInfo(.Attic, jd + 1, true, true)).main_date.day;

            if (include_time_of_day) {
                const midnight_hour = (midnight_in_attic - math.floor(midnight_in_attic)) * 24;
                const hour = (date.day - math.floor(date.day)) * 24; // In attic

                jd += 1;
                const sun_rise_set = astronomy.getTimeOfSunTransitRiseSet(jd, false, true, true);

                if (hour >= 12 and hour >= midnight_hour) // Before sunrise
                {
                    const prev_day_sunset = astronomy.getTimeOfSunTransitRiseSet(jd - 1, false, false, true)[2];
                    const segment_length = (sun_rise_set[1] - prev_day_sunset) / 12; // length of attic hour in gregorian hours
                    const day_fraction = (hour - midnight_hour) * @abs(segment_length); // fraction in gregorian
                    jd += day_fraction;
                } else if (hour >= 12 and hour < midnight_hour) // After sunset //gud
                {
                    const next_day_sunrise = astronomy.getTimeOfSunTransitRiseSet(jd + 1, false, true, false)[1];
                    const segment_length = (next_day_sunrise - sun_rise_set[2]) / 12;
                    const day_fraction = (hour - midnight_hour) * @abs(segment_length);
                    jd += day_fraction;
                } else // Mid day //gud
                {
                    const segment_length = (sun_rise_set[2] - sun_rise_set[1]) / 12;
                    const day_fraction = hour * segment_length + sun_rise_set[1];
                    jd += day_fraction - 1;
                }
            } else {
                if (date.day > midnight_in_attic) jd += 1;
            }
        }
        return jd;
    } else {
        return try gregorianToJD(date);
    }
}
// See getDateInfo() for notes, including proper_date meaning
pub fn jdToDate(calendar: CalendarType, jd: f64, proper_date: bool, include_time_of_day: bool) !Date {
    if (calendar == .Attic) {
        return (try getDateInfo(.Attic, jd, proper_date, include_time_of_day)).main_date;
    } else {
        return jdToGregorian(jd);
    }
}

pub fn jdToGregorian(jd: f64) Date {
    // Chapter 7, pdf page 71

    const jd05 = jd + 0.5;
    const Z = math.trunc(jd05);
    const F = jd05 - Z;
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
        var day_count = getGregorianMonthDayCount(self.year, self.month);
        while (day_count > self.day) { // Later month
            self.day -= day_count;
            self.month += 1;
            // self.normaliseMonth();
            day_count = getGregorianMonthDayCount(self.year, self.month);
        }
    }
}

pub fn now() f64 {
    var jd: f64 = 2440587.5; // Epoch 01/01/1970
    jd += @as(f64, @floatFromInt(std.time.timestamp())) / 86400;
    return jd;
}
