const std = @import("std");
const sdl = @import("sdl.zig");

export fn SDL_main() void {
    sdl.main();
}
pub fn main() !void {
    // const dates = @import("dates.zig");
    // const proper_date = true;
    // std.debug.print("aaaaaaaa: {dt}\n", .{try dates.jdToDate(.Attic, 2460764.5, proper_date, false)});
    // std.debug.print("aaaaaaaa: {dt}\n", .{try dates.jdToDate(.Attic, 2460734.5, proper_date, false)});
    // std.debug.print("aaaaaaaa: {dt}\n", .{try dates.jdToDate(.Attic, 2460826.5, proper_date, false)});
    // std.debug.print("aaaaaaaa: {dt}\n", .{try dates.jdToDate(.Attic, 2460850.5, proper_date, false)});
    // std.debug.print("aaaaaaaa: {dt}\n", .{try dates.jdToDate(.Attic, 2460851.5, proper_date, false)});
    // std.debug.print("aaaaaaaa: {dt}\n", .{try dates.jdToDate(.Attic, 2460852.5, proper_date, false)});
    // std.debug.print("aaaaaaaa: {dt}\n", .{try dates.jdToDate(.Attic, 2460853.5, proper_date, false)});
    // std.debug.print("aaaaaaaa: {dt}\n", .{try dates.jdToDate(.Attic, 2460854.5, proper_date, false)});
    // std.debug.print("aaaaaaaa: {dt}\n", .{try dates.jdToDate(.Attic, 2460855.5, proper_date, false)});
    // std.debug.print("aaaaaaaa: {dt}\n", .{try dates.jdToDate(.Attic, 2460856.5, proper_date, false)});

    sdl.main();

    // var shortest_year: f64 = 1000;
    // var year: i32 = 1900 + 779;
    // while (year < 2100 + 779) {
    //     const first_of_the_year = try dates.dateToJD(dates.Date.init(year, 1, 1, .Attic), false, false);
    //     const first_of_the_year_data = try dates.getDateInfo(.Attic, first_of_the_year, false, false);
    //     const first_of_last_month = try dates.dateToJD(dates.Date.init(year, first_of_the_year_data.months_in_year, 1, .Attic), false, false);
    //     const first_of_last_month_data = try dates.getDateInfo(.Attic, first_of_last_month, false, false);
    //     const first_of_the_next_year = first_of_last_month + @as(f64, @floatFromInt(first_of_last_month_data.days_in_month)) - 1;

    //     const year_length = first_of_the_next_year - first_of_the_year;
    //     if (year_length < shortest_year) shortest_year = year_length;
    //     year += 1;
    // }
    // std.debug.print("\n\nShortest year: {d}\n", .{shortest_year});
}
