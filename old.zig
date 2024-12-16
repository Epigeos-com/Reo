pub fn countTotalDays(self: date) !date {
    if (self.calendar == .Attic) {
        return error.NotImplemented;
    } else {
        const isLastYearLeap = isGregorianYearLeap(self.year);
        var leapYearCount: i32 = 0;
        if (self.year > 1582) {
            const leapYearCountJulian = comptime @divFloor((1582), 4);
            const leapYearCountGregorian = @divFloor((self.year - 1580), 4) - @divFloor((self.year - 1580), 100) + @divFloor((self.year - 1580), 400);
            leapYearCount = leapYearCountJulian + leapYearCountGregorian;
        } else {
            leapYearCount = @divFloor((self.year), 4);
        }
        if (isLastYearLeap) leapYearCount -= 1;

        const nonLeapYearCount = self.year - leapYearCount - 1;
        var daysFromYear: f64 = @floatFromInt(nonLeapYearCount * 365 + leapYearCount * 366);
        if (self.year >= 1582) daysFromYear -= 10; // 10 days were skipped when julian was changed to gregorian

        var daysFromMonth: f64 = 0;
        for (1..@intCast(self.month)) |i| {
            daysFromMonth += try daysInGregorianMonth(@intCast(i), isLastYearLeap);
        }

        var newSelf = self;
        newSelf.totalDays = self.day - 1 + daysFromMonth - 1 + daysFromYear - 1;
        return newSelf;
    }
}
pub fn isGregorianYearLeap(year: i32) bool {
    return if (year > 1582) (@mod(year, 4) == 0 and (@mod(year, 100) != 0 or @mod(year, 400) == 0)) else (@mod(year, 4) == 0);
}
pub fn daysInGregorianMonth(month: u8, isLeap: bool) !f64 {
    return switch (month) {
        1 => 31,
        2 => if (isLeap) 29 else 28,
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
// Basic operations for the gregorian calendar are here, because they are needed for various functions, they themselves are not a part of the calendar system
