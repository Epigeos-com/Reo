const dates = @import("Dates.zig");
const std = @import("std");

//pub const envPath: []u8 = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData) + "/Epigeos/Hydor/Reo";
pub var gpallocator = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpallocator.allocator();

pub var primaryCalendar: dates.calendarType = .Attic;
pub var secondaryCalendar: dates.calendarType = .Gregorian;

pub var anniversaryCalendar: bool = true; // True - primary, false - secondary
pub var anniversaryCalendarConfirmed: bool = true; // Set to lightMode when settings are saved or loaded to prevent icons from changing modes before settings are closed

pub var useLowPrecisionForNutationEpsilon0: bool = false;
pub var useLowPrecisionForSunTransit: bool = true;

pub var longitude: f64 = 37.976234;
pub var latitude: f64 = 23.721661;

// Gregorian
pub var useAmPmInGregorian: bool = false;

// Attic
pub var monthToDoubleInAttic: i8 = 6;
pub var doubledMonthNameFormattingInAttic: []u8 = "{originalName} II";
pub var romaniseMonthNamesInAttic: bool = false;
pub var dayStringInAttic = "";
pub var nightStringInAttic = " night";

// Default events
pub var internationalSDE: bool = true;
pub var christianSDE: bool = false;
pub var hellenicReligiousSDE: bool = true;
pub var newMoonsSDE: bool = false;
pub var fullMoonsSDE: bool = true;
pub var solsticesEqinoxesSDE: bool = true;

pub var presaveAstronomyEventsForGregorianMonths: u8 = 3 * 12; // This many months from today backwards and forwards
