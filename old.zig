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
