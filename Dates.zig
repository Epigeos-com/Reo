const std = @import("std");
const math = std.math;
const settings = @import("Settings.zig");

pub const date: type = struct {
    year: i32 = 0,
    month: i8 = 0,
    day: f64 = 0,
    calendar: calendarType = .Gregorian,

    pub fn init(year: i32, month: i8, day: f64, calendar: calendarType) date {
        const bareDate = date{ .year = year, .month = month, .day = day, .calendar = calendar };
        return bareDate;
    }
    pub fn format(self: date, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        const dayT = math.trunc(self.day);
        const hours = (self.day - dayT) * 24;
        const hoursT = math.trunc(hours);
        const minutes = (hours - hoursT) * 60;
        const minutesT = math.trunc(minutes);
        const seconds = (minutes - minutesT) * 60;
        if (self.calendar == .Attic) {
            const olympiad = @divFloor(self.year, 4);
            const year = self.year - (olympiad * 4) + 1;
            try writer.print("{d}/{d}/O{d}Y{d} {d:0>2}:{d:0>2}:{d:0>2}", .{ dayT, self.month, olympiad, year, hoursT, minutesT, seconds });
        } else {
            try writer.print("{d}/{d}/{d} {d:0>2}:{d:0>2}:{d:0>2}", .{ dayT, self.month, self.year, hoursT, minutesT, seconds });
        }
    }
};
pub const calendarType: type = enum { Gregorian, Attic };
pub const calendarTypeSetting: type = enum { primary, secondary, anniversary, Gregorian, Attic };

pub fn JDToGregorian(JD: f64) date {
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
    return date.init(year, month, day, .Gregorian);
}
pub fn gregorianToJD(adate: date) !f64 {
    if (adate.calendar != .Gregorian) return error.WrongCalendar;
    var year = adate.year;
    var month = adate.month;
    const day = adate.day;
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
