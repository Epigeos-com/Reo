using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace Reo
{
    public class Dates
    {
        public enum CalendarType
        {
            Gregorian,
            Attic
        }
        public enum CalendarTypeSetting
        {
            primary,
            secondary,
            anniversary,
            Gregorian,
            Attic
        }
        public static CalendarType ConvertCalendarTypeSetting(int calendarTypeSetting)
        {
            if (calendarTypeSetting < 3)
            {
                switch (calendarTypeSetting)
                {
                    case 0: return Settings.primaryCalendar;
                    case 1: return Settings.secondaryCalendar;
                    default: return Settings.anniversaryCalendarConfirmed ? Settings.primaryCalendar : Settings.secondaryCalendar;
                };
            }
            else
            {
                return (CalendarType)(calendarTypeSetting - 3);
            }
        }
        public struct DateInfo
        {
            public ValueTuple<int, int, double> date;
            public DateTime firstOfTheYearInGregorian;
            public DateTime firstOfTheMonthInGregorian;
            public int monthsInYear;
            public int daysInMonth;
            public int rowSize;
            public int minRows;
            public string yearName;
            public string monthName;

            public DateInfo(ValueTuple<int, int, double> date, DateTime firstOfTheYearInGregorian, DateTime firstOfTheMonthInGregorian, int monthsInYear, int daysInMonth, int rowSize, int minRows, string yearName, string monthName) : this()
            {
                this.date = date;
                this.firstOfTheYearInGregorian = firstOfTheYearInGregorian;
                this.firstOfTheMonthInGregorian = firstOfTheMonthInGregorian;
                this.monthsInYear = monthsInYear;
                this.daysInMonth = daysInMonth;
                this.rowSize = rowSize;
                this.minRows = minRows;
                this.yearName = yearName;
                this.monthName = monthName;
            }
            public DateInfo(DateTime firstOfTheYearInGregorian, DateTime firstOfTheMonthInGregorian, int monthsInYear, int daysInMonth, int rowSize, int minRows, string yearName, string monthName) : this()
            {
                this.firstOfTheYearInGregorian = firstOfTheYearInGregorian;
                this.firstOfTheMonthInGregorian = firstOfTheMonthInGregorian;
                this.monthsInYear = monthsInYear;
                this.daysInMonth = daysInMonth;
                this.rowSize = rowSize;
                this.minRows = minRows;
                this.yearName = yearName;
                this.monthName = monthName;
            }
            public override string ToString()
            {
                return $"date:{date}, firstOfTheYearInGregorian:{firstOfTheYearInGregorian}, firstOfTheMonthInGregorian:{firstOfTheMonthInGregorian}, monthsInYear:{monthsInYear}, daysInMonth:{daysInMonth}, rowSize:{rowSize}, minRows:{minRows}, yearName:{yearName}, monthName:{monthName}";
            }
        }
        // properDate means whether in calendars starting days at different times than the Gregorian the time of day should be counted for the date, doesn't matter when includeTimeOfDay is true
        // properDate and includeTimeOfDay do use more resources for some calendars, so they should not be used when it's not necessary
        public static DateInfo GetDateInfo(CalendarType calendar, DateTime gregorianDate, bool properDate, bool includeTimeOfDay)
        {
            var outputDate = new ValueTuple<int, int, double>();
            var firstOfTheYearInGregorian = new DateTime();
            var firstOfTheMonthInGregorian = new DateTime();
            var monthsInYear = 12;
            var daysInMonth = 30;
            var rowSize = 7;
            var minRows = 5;
            var yearName = "1970";
            var monthName = "Invalid month";

            var date = gregorianDate;
            if (calendar == CalendarType.Gregorian)
            {
                firstOfTheYearInGregorian = new DateTime(date.Year, 1, 1);
                firstOfTheMonthInGregorian = new DateTime(date.Year, date.Month, 1);

                outputDate = new ValueTuple<int, int, double>(date.Year, date.Month, date.Day + (includeTimeOfDay ? ((double)date.Hour / 24 + (double)date.Minute / 1440 + (double)date.Second / 86400) : 0));

                monthsInYear = 12;
                rowSize = 7;
                minRows = 5;

                yearName = date.Year.ToString();
                daysInMonth = DateTime.DaysInMonth(date.Year, date.Month);
                var monthNames = new List<string>() { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };
                monthName = monthNames[date.Month - 1];
            }
            else if (calendar == CalendarType.Attic)
            {
                if (!properDate && !includeTimeOfDay) date = date.AddHours(12);
                if (date == RoundDateTime(date, CalendarType.Gregorian)) date = date.AddMilliseconds(1);
                int year = 0;
                firstOfTheYearInGregorian = RoundDateTime(Astronomy.GetClosestSunPhase(date, out year, false, 2), calendar);
                double k = 0;
                firstOfTheYearInGregorian = CeilingDateTime(Astronomy.GetClosestMoonPhase(firstOfTheYearInGregorian, out k, true), calendar);

                var nextFirstOfTheYearBasedOnSolstice = RoundDateTime(Astronomy.GetClosestSunPhase(date, true, 2), calendar);

                if (firstOfTheYearInGregorian.Date > FloorDateTime(date, calendar)) // For when date is after solstice, but before first new moon of the year
                {
                    nextFirstOfTheYearBasedOnSolstice = RoundDateTime(Astronomy.GetDateForSunPhase(year, 2), calendar);
                    year--;
                    firstOfTheYearInGregorian = RoundDateTime(Astronomy.GetDateForSunPhase(year, 2), calendar);
                    firstOfTheYearInGregorian = CeilingDateTime(Astronomy.GetClosestMoonPhase(firstOfTheYearInGregorian, out k, true), calendar);
                }

                monthsInYear = 0;
                var newMoon = firstOfTheYearInGregorian;
                var monthBeginnings = new List<DateTime>();
                while (newMoon <= nextFirstOfTheYearBasedOnSolstice)
                {
                    monthBeginnings.Add(newMoon);
                    k++;
                    newMoon = CeilingDateTime(Astronomy.GetDateForMoonPhase(k), calendar);
                    monthsInYear++;
                }
                var firstOfTheNextYear = CeilingDateTime(Astronomy.GetDateForMoonPhase(k), calendar);

                firstOfTheMonthInGregorian = monthBeginnings.Where(element => element <= date).Max();

                year += 779;
                var olympiad = Math.Floor((double)year / 4);
                yearName = $"O{olympiad}Y{year - olympiad * 4 + 1}";
                var month = monthBeginnings.IndexOf(firstOfTheMonthInGregorian) + 1; // +1 because of lists starting at 0
                var dayUnrounded = (date - firstOfTheMonthInGregorian).TotalDays;
                var day = Math.Ceiling((date - firstOfTheMonthInGregorian).TotalDays);

                if (properDate || includeTimeOfDay)
                {
                    var dayFraction = dayUnrounded - Math.Floor(dayUnrounded);
                    var JD = Astronomy.GregorianToJD(GregorianToDate(CalendarType.Gregorian, gregorianDate, false, false));
                    var utcOffset = 0;
                    var sunrise = Astronomy.GetTimeOfSunTransitRiseSet(JD, utcOffset, false, true, false);

                    if (!includeTimeOfDay)
                    {
                        if (dayFraction < sunrise.Item2) // Before sunrise
                        {
                            day--;
                        }
                    }
                    else
                    {
                        var sunset = Astronomy.GetTimeOfSunTransitRiseSet(JD, utcOffset, false, false, true);
                        if (dayFraction < sunrise.Item2) // Before sunrise
                        {
                            var prevDaySunset = Astronomy.GetTimeOfSunTransitRiseSet(JD - 1, utcOffset, false, false, true).Item3;
                            var segmentLength = (sunrise.Item2 - prevDaySunset) / 12;
                            var hour = (sunrise.Item2 - dayFraction) / segmentLength;
                            day += hour / 24;
                        }
                        else if (dayFraction > sunset.Item3) // After sunset
                        {
                            var nextDaySunrise = Astronomy.GetTimeOfSunTransitRiseSet(JD + 1, utcOffset, false, true, false).Item2;
                            var segmentLength = (nextDaySunrise - sunset.Item3) / 12;
                            var hour = (nextDaySunrise - dayFraction) / segmentLength;
                            day += hour / 24;
                        }
                        else // Mid day
                        {
                            var segmentLength = (sunset.Item3 - sunrise.Item2) / 12;
                            var hour = (dayFraction - sunrise.Item2) / segmentLength;
                            day += hour / 24;
                        }
                    }

                    if (day < 1) return GetDateInfo(calendar, gregorianDate.AddDays(-.5), properDate, includeTimeOfDay); // TODO
                }

                if (Math.Abs(Math.Round(day) - day) < 0.001) day = Math.Round(day);
                outputDate = new ValueTuple<int, int, double>(year, month, day);

                var firstOfTheNextMonth = new DateTime();
                try
                {
                    firstOfTheNextMonth = CeilingDateTime(monthBeginnings[month], calendar);
                }
                catch
                {
                    firstOfTheNextMonth = CeilingDateTime(firstOfTheNextYear, calendar);
                }
                daysInMonth = (int)(firstOfTheNextMonth - firstOfTheMonthInGregorian).TotalDays;

                List<string> monthNames = Settings.romaniseMonthNamesInAttic ? (new List<string>() { "Ekatombaion", "Metageitnion", "Boedromion", "Pyanepsion", "Maimakterion", "Poseideon", "Gamelion", "Anthesterion", "Elaphebolion", "Mounichion", "Thargelion", "Skirophorion" }) : (new List<string>() { "Ἑκατομβαιών", "Μεταγειτνιών", "Βοηδρομιών", "Πυανεψιών", "Μαιμακτηριών", "Ποσειδεών", "Γαμηλιών", "Ἀνθεστηριών", "Ἐλαφηβολιών", "Μουνυχιών", "Θαργηλιών", "Σκιροφοριών" });
                if (monthsInYear == 13) monthNames.Insert(Settings.monthToDoubleInAttic, Settings.doubledMonthNameFormattingInAttic.Replace("{originalName}", monthNames[Settings.monthToDoubleInAttic - 1]));
                monthName = monthNames[month - 1];

                rowSize = 5;
                minRows = 6;
            }

            return new DateInfo(outputDate, firstOfTheYearInGregorian, firstOfTheMonthInGregorian, monthsInYear, daysInMonth, rowSize, minRows, yearName, monthName);
        }

        public static ValueTuple<int, int, double> ParseDate(string date, CalendarType calendar)
        {
            if (calendar == CalendarType.Gregorian)
            {
                var dateTime = DateTime.Parse(date);
                return new ValueTuple<int, int, double>(dateTime.Year, dateTime.Month, dateTime.Day + (double)dateTime.Hour / 24 + (double)dateTime.Minute / 1440 + (double)dateTime.Second / 86400);
            }
            else if (calendar == CalendarType.Attic) // 1/1/O1Y1 1.8       1/1/1 1.8     1/1/O1Y1 2:30
            {
                var split = date.Split(' ');
                var dayDate = Regex.Split(split[0], "[\\/]");

                double day = int.Parse(dayDate[0]);
                if (split.Length > 1)
                {
                    if (split[1].Contains(':'))
                    {
                        var time = split[1].Split(':');
                        day += int.Parse(time[0]) / 24 + double.Parse(time[1]) / 1440;
                    }
                    else
                    {
                        day += double.Parse(split[1]) / 24;
                    }
                    var night = new string[5] { "night", "νύξ", "nix", "nyx", "pm" };
                    if (split.Length == 3 && day - Math.Floor(day) <= .5 && night.Contains(split[2].ToLower()))
                    {
                        day += .5;
                    }
                }

                var year = 0;
                if (dayDate[2].Contains('O'))
                {
                    var regex = Regex.Match(dayDate[2], "O(\\d+)Y([1234])");
                    year = 4 * int.Parse(regex.Groups[1].Value) + int.Parse(regex.Groups[2].Value) - 1;
                }
                else
                {
                    year = int.Parse(dayDate[2]);
                }

                return new ValueTuple<int, int, double>(year, int.Parse(dayDate[1]), day);
            }
            return new ValueTuple<int, int, double>();
        }
        public static string DeparseDate(ValueTuple<int, int, double> date, CalendarType calendar, bool timeOfDayOnly = false, bool secondPrecision = false)
        {
            if (calendar == CalendarType.Gregorian)
            {
                var timeString = "";
                var day = Math.Floor(date.Item3);
                if (day != date.Item3)
                {
                    var totalHour = (date.Item3 - day) * 24;
                    var hour = Math.Floor(totalHour);
                    var totalMinute = (totalHour - hour) * 60;

                    if (secondPrecision)
                    {
                        var minute = Math.Floor(totalMinute);
                        var totalSecond = (totalMinute - minute) * 60;

                        timeString = $" {hour:00}:{minute:00}:{totalSecond:00}";
                    }
                    else
                    {
                        var minute = Math.Round(totalMinute);

                        timeString = $" {hour:00}:{minute:00}";
                    }
                }

                if (timeOfDayOnly)
                {
                    return timeString.Substring(1);
                }
                else
                {
                    return $"{day}/{date.Item2}/{date.Item1}{timeString}";
                }
            }
            else if (calendar == CalendarType.Attic) // 1/1/O1Y1 1.8
            {
                var timeString = "";
                var day = Math.Floor(date.Item3);
                if (day != date.Item3)
                {
                    var totalHour = (date.Item3 - day) * 24;
                    var isNight = false;
                    if (totalHour > 12)
                    {
                        totalHour -= 12;
                        isNight = true;
                    }
                    totalHour = Math.Round(totalHour, secondPrecision ? 3 : 2);
                    timeString = " " + totalHour.ToString("0.0") + (isNight ? " nyx" : "");
                }

                if (timeOfDayOnly)
                {
                    return timeString.Substring(1);
                }
                else
                {
                    var olympiad = Math.Floor((double)date.Item1 / 4);
                    var year = date.Item1 - 4 * olympiad + 1;
                    return $"{day}/{date.Item2}/O{olympiad}Y{year}{timeString}";
                }
            }
            return null;
        }

        // See GetDateInfo() for notes, including properDate meaning
        public static DateTime DateToGregorian(CalendarType calendar, ValueTuple<int, int, double> date, bool properDate, bool includeTimeOfDay)
        {
            if (calendar == CalendarType.Attic)
            {
                var dateTime = new DateTime(date.Item1 - 779, 1, 1).AddDays(date.Item3 + 5).AddMonths(date.Item2 + 5);
                var dateInfo = GetDateInfo(calendar, dateTime, false, false);
                while (dateInfo.date.Item2 != date.Item2)
                {
                    dateTime = dateTime.AddDays(dateInfo.date.Item2 < date.Item2 ? 28 : -28);
                    dateInfo = GetDateInfo(calendar, dateTime, false, false);
                }
                dateTime = dateTime.AddDays(date.Item3 - dateInfo.date.Item3);
                dateTime = FloorDateTime(dateTime, CalendarType.Gregorian);

                if (includeTimeOfDay || properDate)
                {
                    var midnightInAttic = GetDateInfo(calendar, dateTime, true, true).date.Item3;
                    if (Math.Floor(midnightInAttic) < Math.Floor(date.Item3)) midnightInAttic = GetDateInfo(calendar, dateTime.AddDays(1), true, true).date.Item3;

                    if (includeTimeOfDay)
                    {
                        var midnightHour = (midnightInAttic - Math.Floor(midnightInAttic)) * 24;
                        var hour = (date.Item3 - Math.Floor(date.Item3)) * 24; // In attic

                        var JD = Astronomy.GregorianToJD(GregorianToDate(CalendarType.Gregorian, dateTime, false, false)) + 1; // TODO
                        var utcOffset = 0;
                        var sunRiseSet = Astronomy.GetTimeOfSunTransitRiseSet(JD, utcOffset, false, true, true);

                        if (hour >= 12 && hour >= midnightHour) // Before sunrise
                        {
                            var prevDaySunset = Astronomy.GetTimeOfSunTransitRiseSet(JD - 1, utcOffset, false, false, true).Item3;
                            var segmentLength = (sunRiseSet.Item2 - prevDaySunset) / 12; // length of attic hour in gregorian hours
                            var dayFraction = (hour - midnightHour) * Math.Abs(segmentLength); // fraction in gregorian
                            dateTime = dateTime.AddDays(dayFraction + 1);
                        }
                        else if (hour >= 12 && hour < midnightHour) // After sunset //gud
                        {
                            var nextDaySunrise = Astronomy.GetTimeOfSunTransitRiseSet(JD + 1, utcOffset, false, true, false).Item2;
                            var segmentLength = (nextDaySunrise - sunRiseSet.Item3) / 12;
                            var dayFraction = (hour - midnightHour) * Math.Abs(segmentLength);
                            dateTime = dateTime.AddDays(dayFraction + 1);
                        }
                        else // Mid day //gud
                        {
                            var segmentLength = (sunRiseSet.Item3 - sunRiseSet.Item2) / 12;
                            var dayFraction = hour * segmentLength + sunRiseSet.Item2;
                            dateTime = dateTime.AddDays(dayFraction);
                        }
                    }
                    else
                    {
                        if (date.Item3 > midnightInAttic) dateTime = dateTime.AddDays(1);
                    }
                }
                return dateTime;
            }
            else
            {
                return new DateTime(date.Item1, date.Item2, 1).AddDays(date.Item3 - 1);
            }
        }
        // See GetDateInfo() for notes, including properDate meaning
        public static ValueTuple<int, int, double> GregorianToDate(CalendarType calendar, DateTime date, bool properDate, bool includeTimeOfDay)
        {
            if (calendar == CalendarType.Attic)
            {
                var dateInfo = GetDateInfo(calendar, date, properDate, includeTimeOfDay);
                return dateInfo.date;
            }
            else
            {
                return new ValueTuple<int, int, double>(date.Year, date.Month, date.Day + (includeTimeOfDay ? ((double)date.Hour / 24 + (double)date.Minute / 1440 + (double)date.Second / 86400) : 0));
            }
        }
        // Equivalent to DateToGregorian(Gregorian, ...)
        public static DateTime GregorianTupleToDatetime(ValueTuple<int, int, double> date){
            return new DateTime(date.Item1, date.Item2, 1).AddDays(date.Item3 - 1);
        }


        public static DateTime CeilingDateTime(DateTime date, CalendarType calendarType)
        {
            if (calendarType == CalendarType.Attic)
            {
                var JD = Astronomy.GregorianToJD(GregorianToDate(CalendarType.Gregorian, date, false, false));
                var utcOffset = 0;
                date = date.AddDays(-Astronomy.GetTimeOfSunTransitRiseSet(JD, utcOffset, false, true, false).Item2);
            }

            var output = new DateTime(date.Year, date.Month, date.Day, 0, 0, 0);
            if (date.Hour > 0 || date.Minute > 0 || date.Second > 0) output = output.AddDays(1);
            return output;
        }
        public static DateTime FloorDateTime(DateTime date, CalendarType calendarType)
        {
            if (calendarType == CalendarType.Attic)
            {
                var JD = Astronomy.GregorianToJD(GregorianToDate(CalendarType.Gregorian, date, false, false));
                var utcOffset = 0;
                date = date.AddDays(-Astronomy.GetTimeOfSunTransitRiseSet(JD, utcOffset, false, true, false).Item2);
            }

            var output = new DateTime(date.Year, date.Month, date.Day, 0, 0, 0);
            return output;
        }
        public static DateTime RoundDateTime(DateTime date, CalendarType calendarType)
        {
            if (calendarType == CalendarType.Attic)
            {
                var JD = Astronomy.GregorianToJD(GregorianToDate(CalendarType.Gregorian, date, false, false));
                var utcOffset = 0;
                date = date.AddDays(-Astronomy.GetTimeOfSunTransitRiseSet(JD, utcOffset, false, true, false).Item2);
            }

            var output = new DateTime(date.Year, date.Month, date.Day, 0, 0, 0);
            if (date.Hour >= 12 || date.Minute >= 12 || date.Second >= 12) output = output.AddDays(1);
            return output;
        }
    }
}
