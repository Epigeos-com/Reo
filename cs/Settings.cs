using System;

namespace Reo
{
    internal class Settings
    {
        public static string envPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData) + "/Epigeos/Hydor/Reo";

        public static Dates.CalendarType primaryCalendar = Dates.CalendarType.Attic;
        public static Dates.CalendarType secondaryCalendar = Dates.CalendarType.Gregorian;

        public static bool anniversaryCalendar; // True - primary, false - secondary
        public static bool anniversaryCalendarConfirmed; // Set to lightMode when settings are saved or loaded to prevent icons from changing modes before settings are closed

        public static bool useLowPrecisionForSunTransit = true;

        public static double longitude = 37.976234;
        public static double latitude = 23.721661;


        // Attic
        public static int monthToDoubleInAttic = 6;
        public static string doubledMonthNameFormattingInAttic = "{originalName} II";
        public static bool romaniseMonthNamesInAttic = false;

        // Default events
        public static bool internationalSDE = true;
        public static bool christianSDE = false;
        public static bool hellenicReligiousSDE = true;
        public static bool newMoonsSDE = false;
        public static bool fullMoonsSDE = true;
        public static bool solsticesEqinoxesSDE = true;

        public static int presaveAstronomyEventsForGregorianMonths = 3 * 12; // This many months from today backwards and forwards
    }
}
