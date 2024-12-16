using System;
using System.Collections.Generic;
using System.Linq;

namespace Reo
{
    internal class Astronomy
    {
        public static double GregorianToJD(ValueTuple<int, int, double> date)
        {
            var years = date.Item1;
            var months = date.Item2;
            var days = date.Item3;
            // Chapter 7, pdf page 69

            if (months <= 2)
            {
                years--;
                months += 12;
            }
            var A = (int)Math.Truncate((float)years / 100);
            var B = 0;
            if (years >= 1582) // when Gregorian was created
            {
                if (years > 1582 || months >= 10)
                {
                    if (years > 1582 || months > 10 || days >= 15.5)
                    {
                        B = 2 - A + (int)Math.Truncate((float)A / 4);
                    }
                }
            }
            var JD = Math.Truncate(365.25 * (years + 4716)) + Math.Truncate(30.6001 * (months + 1)) + days + B - 1524.5;
            return JD;
        }
        public static DateTime JDToGregorian(double JD)
        {
            // Chapter 7, pdf page 71

            JD += .5;
            var Z = Math.Truncate(JD);
            var F = JD - Z;
            var A = Z;
            if (Z >= 2299161) // or 2291161??
            {
                var α = Math.Truncate((Z - 1867216.25) / 36524.25);
                A = Z + 1 + α - Math.Truncate(α / 4);
            }
            var B = A + 1524;
            var C = Math.Truncate((B - 122.1) / 365.25);
            var D = Math.Truncate(365.25 * C);
            var E = Math.Truncate((B - D) / 30.6001);
            var days = B - D - Math.Truncate(30.6001 * E) + F;
            var months = E - 1;
            if (E >= 14)
            {
                months = E - 13;
            }
            var years = C - 4716;
            if (months <= 2)
            {
                years = C - 4715;
            }
            return new DateTime((int)years, (int)months, 1).AddDays(days - 1);
        }

        // k is which moon phase it is from the new moon of 6 Jan 2000 plus 0 for new moon, .25 for first quarter, .5 for full moon, .75 for last quarter(not all implemented yet)
        public static DateTime GetDateForMoonPhase(double k)
        {
            var T = k / 1236.85;
            var JD = 2451550.09766 + 29.530588861 * k + 0.00015437 * T * T - 0.00000015 * T * T * T + 0.00000000073 * T * T * T * T;

            var E = 1 - 0.002516 * T - 0.0000074 * T * T;
            var M = (2.5534 + 29.10535670 * k - 0.0000014 * T * T - 0.00000011 * T * T * T) * Math.PI / 180;
            var Mp = (201.5643 + 385.81693528 * k + 0.0107582 * T * T + 0.00001238 * T * T * T - 0.000000058 * T * T * T * T) * Math.PI / 180;
            var F = (160.7108 + 390.67050284 * k - 0.0016118 * T * T - 0.00000227 * T * T * T + 0.000000011 * T * T * T * T) * Math.PI / 180;
            var Ω = (124.7746 - 1.56375588 * k + 0.0020672 * T * T + 0.00000215 * T * T * T) * Math.PI / 180;

            var A1 = (299.77 + 0.107408 * k - 0.009173 * T * T) * Math.PI / 180;
            var A2 = (251.88 + 0.016321 * k) * Math.PI / 180;
            var A3 = (251.83 + 26.651886 * k) * Math.PI / 180;
            var A4 = (349.42 + 36.412478 * k) * Math.PI / 180;
            var A5 = (84.66 + 18.206239 * k) * Math.PI / 180;
            var A6 = (141.74 + 53.303771 * k) * Math.PI / 180;
            var A7 = (207.14 + 2.453732 * k) * Math.PI / 180;
            var A8 = (154.84 + 7.306860 * k) * Math.PI / 180;
            var A9 = (34.52 + 27.261239 * k) * Math.PI / 180;
            var A10 = (207.19 + 0.121824 * k) * Math.PI / 180;
            var A11 = (291.34 + 1.844379 * k) * Math.PI / 180;
            var A12 = (161.72 + 24.198154 * k) * Math.PI / 180;
            var A13 = (239.56 + 25.513099 * k) * Math.PI / 180;
            var A14 = (331.55 + 3.592518 * k) * Math.PI / 180;
            if (Math.Round(k) == k)
            {
                JD += -0.4072 * Math.Sin(Mp) + 0.17241 * E * Math.Sin(M) + 0.01608 * Math.Sin(2 * Mp) + 0.01039 * Math.Sin(2 * F) + 0.00739 * E * Math.Sin(Mp - M) - 0.00514 * E * Math.Sin(Mp + M) + 0.00208 * E * E * Math.Sin(2 * M) - 0.00111 * Math.Sin(Mp - 2 * F) - 0.00057 * Math.Sin(Mp + 2 * F) + 0.00056 * E * Math.Sin(2 * Mp + M) - 0.00042 * Math.Sin(3 * Mp) + 0.00042 * E * Math.Sin(M + 2 * F) + 0.00038 * E * Math.Sin(M - 2 * F) - 0.00024 * E * Math.Sin(2 * Mp - M) - 0.00017 * Math.Sin(Ω) - 0.00007 * Math.Sin(Mp + 2 * M) + 0.00004 * Math.Sin(2 * Mp - 2 * F) + 0.00004 * Math.Sin(3 * M) + 0.00003 * Math.Sin(Mp + M - 2 * F) + 0.00003 * Math.Sin(2 * Mp + 2 * F) - 0.00003 * Math.Sin(Mp + M + 2 * F) + 0.00003 * Math.Sin(Mp - M + 2 * F) - 0.00002 * Math.Sin(Mp - M - 2 * F) - 0.00002 * Math.Sin(3 * Mp + M) + 0.00002 * Math.Sin(4 * Mp);
            }
            else if (Math.Ceiling(k) - .5 == k)
            {
                JD += -0.40614 * Math.Sin(Mp) + 0.17302 * E * Math.Sin(M) + 0.01614 * Math.Sin(2 * Mp) + 0.01043 * Math.Sin(2 * F) + 0.00734 * E * Math.Sin(Mp - M) - 0.00515 * E * Math.Sin(Mp + M) + 0.00209 * E * E * Math.Sin(2 * M) - 0.00111 * Math.Sin(Mp - 2 * F) - 0.00057 * Math.Sin(Mp + 2 * F) + 0.00056 * E * Math.Sin(2 * Mp + M) - 0.00042 * Math.Sin(3 * Mp) + 0.00042 * E * Math.Sin(M + 2 * F) + 0.00038 * E * Math.Sin(M - 2 * F) - 0.00024 * E * Math.Sin(2 * Mp - M) - 0.00017 * Math.Sin(Ω) - 0.00007 * Math.Sin(Mp + 2 * M) + 0.00004 * Math.Sin(2 * Mp - 2 * F) + 0.00004 * Math.Sin(3 * M) + 0.00003 * Math.Sin(Mp + M - 2 * F) + 0.00003 * Math.Sin(2 * Mp + 2 * F) - 0.00003 * Math.Sin(Mp + M + 2 * F) + 0.00003 * Math.Sin(Mp - M + 2 * F) - 0.00002 * Math.Sin(Mp - M - 2 * F) - 0.00002 * Math.Sin(3 * Mp + M) + 0.00002 * Math.Sin(4 * Mp);
            }
            else
            {

            }
            JD += (325 * Math.Sin(A1) + 165 * Math.Sin(A2) + 164 * Math.Sin(A3) + 126 * Math.Sin(A4) + 110 * Math.Sin(A5) + 62 * Math.Sin(A6) + 60 * Math.Sin(A7) + 56 * Math.Sin(A8) + 47 * Math.Sin(A9) + 42 * Math.Sin(A10) + 40 * Math.Sin(A11) + 37 * Math.Sin(A12) + 35 * Math.Sin(A13) + 23 * Math.Sin(A14)) / 1000000;
            return JDToGregorian(JD);
        }
        // This is solstices and equinoxes, phase is 0 for December solstice, 1 for March equinox, 2 for June solstice, 3 for September equinox
        public static DateTime GetDateForSunPhase(int year, int phase = 0)
        {
            var Y = ((float)year - 2000) / 1000;
            double JD0 = 0;
            switch (phase){
                case 0: JD0 = 2451900.05952 + 365242.74049 * Y - 0.06223 * Y * Y - 0.00823 * Y * Y * Y + 0.00032 * Y * Y * Y * Y; break;
                case 1: JD0 = 2451810.21715 + 365242.01767 * Y - 0.11575 * Y * Y + 0.00337 * Y * Y * Y + 0.00078 * Y * Y * Y * Y; break;
                case 2: JD0 = 2451716.56767 + 365241.62603 * Y + 0.00325 * Y * Y + 0.00888 * Y * Y * Y - 0.00030 * Y * Y * Y * Y; break;
                default: JD0 = 2451623.80984 + 365242.37404 * Y + 0.05169 * Y * Y - 0.00411 * Y * Y * Y - 0.00057 * Y * Y * Y * Y; break;
            }
            var T = (JD0 - 2451545) / 36525;
            var W = 35999.373 * T - 2.47;
            var Δλ = 1 + 0.0334 * Math.Cos(W * Math.PI / 180) + 0.0007 * Math.Cos(W * Math.PI / 90);
            var S = 485 * Math.Cos((324.96 + 1934.136 * T) * Math.PI / 180) + 45 * Math.Cos((247.54 + 29929.562 * T) * Math.PI / 180) + 203 * Math.Cos((337.23 + 32964.467 * T) * Math.PI / 180) + 44 * Math.Cos((325.15 + 31555.956 * T) * Math.PI / 180) + 199 * Math.Cos((342.08 + 20.186 * T) * Math.PI / 180) + 29 * Math.Cos((60.93 + 4443.417 * T) * Math.PI / 180) + 182 * Math.Cos((27.85 + 445267.112 * T) * Math.PI / 180) + 18 * Math.Cos((155.12 + 67555.328 * T) * Math.PI / 180) + 156 * Math.Cos((73.14 + 45036.886 * T) * Math.PI / 180) + 17 * Math.Cos((288.79 + 4562.452 * T) * Math.PI / 180) + 136 * Math.Cos((171.52 + 22518.443 * T) * Math.PI / 180) + 16 * Math.Cos((198.04 + 62894.029 * T) * Math.PI / 180) + 77 * Math.Cos((222.54 + 65928.934 * T) * Math.PI / 180) + 14 * Math.Cos((199.76 + 31436.921 * T) * Math.PI / 180) + 74 * Math.Cos((296.72 + 3034.906 * T) * Math.PI / 180) + 12 * Math.Cos((95.39 + 14577.848 * T) * Math.PI / 180) + 70 * Math.Cos((243.58 + 9037.513 * T) * Math.PI / 180) + 12 * Math.Cos((287.11 + 31931.756 * T) * Math.PI / 180) + 58 * Math.Cos((119.81 + 33718.147 * T) * Math.PI / 180) + 12 * Math.Cos((320.81 + 34777.259 * T) * Math.PI / 180) + 52 * Math.Cos((297.17 + 150.678 * T) * Math.PI / 180) + 9 * Math.Cos((227.73 + 1222.114 * T) * Math.PI / 180) + 50 * Math.Cos((21.02 + 2281.226 * T) * Math.PI / 180) + 8 * Math.Cos((15.45 + 16859.074 * T) * Math.PI / 180);
            var JD = JD0 + (0.00001 * S) / Δλ;
            return JDToGregorian(JD);
        }
        // 0 - New, 1 - First quarter, 2 - Full, 3 - Last quarter
        public static DateTime GetClosestMoonPhase(DateTime dateTime, bool isForward = true, int phase = 0)
        {
            return GetClosestMoonPhase(dateTime, out var finalK, isForward, phase);
        }
        public static DateTime GetClosestMoonPhase(DateTime dateTime, out double finalK, bool isForward = true, int phase = 0)
        {
            var fracPhase = (double)phase / 4;

            var k = (dateTime.Year - 2000) * 12.3685 + dateTime.Month;
            k = Math.Round(k);
            k += fracPhase;
            var kMoon = GetDateForMoonPhase(k);

            var moons = new List<DateTime>() { kMoon,
                GetDateForMoonPhase(k - 1),
                GetDateForMoonPhase(k + 1),
                GetDateForMoonPhase(k - 2),
                GetDateForMoonPhase(k + 2)
            };

            DateTime moon = moons.Where(element => isForward ? (element >= dateTime) : (element <= dateTime)).OrderBy(element => Math.Max((element - dateTime).TotalDays, (dateTime - element).TotalDays)).First();
            finalK = 0;
            switch (moons.IndexOf(moon))
            {
                case 0: finalK = k; break;
                case 1: finalK = k - 1; break;
                case 2: finalK = k + 1; break;
                case 3: finalK = k - 2; break;
                default: finalK = k + 2; break;
            }
            return moon;
        }
        public static DateTime GetClosestSunPhase(DateTime dateTime, bool isForward = true, int phase = 0)
        {
            return GetClosestSunPhase(dateTime, out var finalYear, isForward, phase);
        }
        public static DateTime GetClosestSunPhase(DateTime dateTime, out int finalYear, bool isForward = true, int phase = 0)
        {
            DateTime[] suns = new DateTime[3] { GetDateForSunPhase(dateTime.Year, phase),
            GetDateForSunPhase(dateTime.Year - 1, phase),
            GetDateForSunPhase(dateTime.Year + 1, phase) };

            var sun = suns.Where(element => isForward ? (element >= dateTime) : (element <= dateTime)).OrderBy(element => Math.Max((element - dateTime).TotalDays, (dateTime - element).TotalDays)).First();
            switch (Array.IndexOf(suns, sun))
            {
                case 0: finalYear = dateTime.Year; break;
                case 1: finalYear = dateTime.Year - 1; break;
                default: finalYear = dateTime.Year + 1; break;
            }
            return sun;
        }

        // (Δψ, ε) in '' (arcsec)
        public static ValueTuple<double, double> GetNutationValues(double JD)
        {
            // Chapter 22, pdf page 152


            // Low accuracy formula for the deltas
            var T = (JD - 2451545) / 36525;
            var D = ((297.85036 + 445267.111480 * T - 0.0019142 * T * T + T * T * T / 189474) % 360) * Math.PI / 180;
            var M = ((357.52772 + 35999.050340 * T - 0.0001603 * T * T + T * T * T / 300000) % 360) * Math.PI / 180;
            var Mp = ((134.96298 + 477198.867398 * T - 0.0086972 * T * T + T * T * T / 56250) % 360) * Math.PI / 180;
            var F = ((93.27191 + 483202.017538 * T - 0.0036825 * T * T + T * T * T / 327270) % 360) * Math.PI / 180;
            // Dropped T: (125.04452 - 1934.136261 * T + 0.0020708 * T * T + T * T * T / 450000)
            var Ω = (125.04452 % 360) * Math.PI / 180;
            var L = (280.4665 + 36000.7698 * T) * Math.PI / 180;
            var Lp = (218.3165 + 481267.8813 * T) * Math.PI / 180;
            
            var Δψ = -17.2 * Math.Sin(Ω) - 1.32 * Math.Sin(2 * L) - 0.23 * Math.Sin(2 * Lp) + 0.21 * Math.Sin(2 * Ω);
            Δψ %= 1296000;
            var Δε = 9.2 * Math.Cos(Ω) + 0.57 * Math.Cos(2 * L) + 0.1 * Math.Cos(2 * Lp) - 0.09 * Math.Cos(2 * Ω);


            // Low accuracy formula
            var ε0 = 84381.448 - 46.8150 * T - 0.00059 * T * T + 0.001813 * T * T * T;
            

            var ε = ε0 + Δε;
            Console.WriteLine("ε0: " + ε0);
            Console.WriteLine("Δε: " + Δε);


            return new ValueTuple<double, double>(Δψ, ε);
        }
        // In h (hour)
        public static double GetApparentSiderealTimeAtGreenwich(double JD)
        {
            // Chapter 12, pdf page 95

            var JD1 = Math.Floor(JD) + .5;
            var T = (JD1 - 2451545) / 36525;

            var Θ0 = (100.46061837 + 36000.770053608 * T + 0.000387933 * T * T - T * T * T / 38710000) % 360;
            var θ0 = ((JD1 - JD) * 1.00273790935 + Θ0) / 15;

            var nutation = GetNutationValues(JD1); // ''
            Console.WriteLine("nutation: " + nutation);
            var θ = θ0 + (nutation.Item1 * Math.Cos(nutation.Item2 * 60 * 60 * 60 * Math.PI / 180)) / (15 * 60 * 60);
            return θ;
        }
        // apparent (ascension, declination), both in °
        public static ValueTuple<double, double> GetPositionOfTheSun(double JD)
        {
            // Chapter 25, pdf page 171
            // Low accuracy method

            var T = (JD - 2451545) / 36525;
            var L0 = 280.46646 + 36000.76983 * T + 0.0003032 * T * T;
            var M = (357.52911 + 35999.05029 * T - 0.0001537 * T * T) * Math.PI / 180;
            var C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * Math.Sin(M) + (0.019993 - 0.000101 * T) * Math.Sin(2 * M) + 0.000289 * Math.Sin(3 * M);

            var O = L0 + C;
            var Ω = (125.04 - 1934.136 * T) * Math.PI / 180;
            var λ = (O - 0.00569 - 0.00478 * Math.Sin(Ω)) * Math.PI / 180;

            var ε = (GetNutationValues(JD).Item2 / (60 * 360) + 0.00256 * Math.Cos(Ω)) * Math.PI / 180;

            var α = Math.Atan2(Math.Cos(ε) * Math.Sin(λ), Math.Cos(λ)) / Math.PI * 180;
            var δ = Math.Asin(Math.Sin(ε) * Math.Sin(λ)) / Math.PI * 180;

            return new ValueTuple<double, double>(α, δ);
        }
        public static ValueTuple<DateTime, DateTime, DateTime> GetTimeOfSunTransitRiseSet(DateTime gregorianDate, double utcOffset = 0, bool getTransit = true, bool getRise = true, bool getSet = true)
        {
            gregorianDate = gregorianDate.Date;
            var result = GetTimeOfSunTransitRiseSet(GregorianToJD(Dates.GregorianToDate(Dates.CalendarType.Gregorian, gregorianDate, false, false)), utcOffset, getTransit, getRise, getSet);
            return new ValueTuple<DateTime, DateTime, DateTime>(gregorianDate.AddDays(result.Item1), gregorianDate.AddDays(result.Item2), gregorianDate.AddDays(result.Item3));
        }
        // In d (day)
        public static ValueTuple<double, double, double> GetTimeOfSunTransitRiseSet(double JD, double utcOffset = 0, bool getTransit = true, bool getRise = true, bool getSet = true)
        {
            // Chapter 15, pdf page 109
            JD = Math.Floor(JD) + .5;
            utcOffset /= 24;

            var L = -Settings.longitude;
            var φ = Settings.latitude * Math.PI / 180;

            var ΔT = GetDynamicTimeDifference(JD);
            var Θ0 = GetApparentSiderealTimeAtGreenwich(JD) * 15;

            var p1 = GetPositionOfTheSun(JD - 1);
            var p2 = GetPositionOfTheSun(JD);
            var p3 = GetPositionOfTheSun(JD + 1);
            Console.WriteLine("JD: " + JD); // right
            Console.WriteLine("ΔT: " + ΔT); // assumed
            Console.WriteLine("Apparent sidereal time at greenwich: " + Θ0 / 15); // close to us data
            Console.WriteLine("p1: " + p1);
            Console.WriteLine("p2: " + p2); // both very wrong
            Console.WriteLine("p3: " + p3);

            var h0 = -0.8333;

            var A = (Math.Sin(h0 * Math.PI / 180) - Math.Sin(φ) * Math.Sin(p2.Item2 * Math.PI / 180)) / (Math.Cos(φ) * Math.Cos(p2.Item2 * Math.PI / 180));
            if (A < -1 || A > 1) return new ValueTuple<double, double, double>(); // Always above horizon
            var H0 = Math.Acos(A) * 180 / Math.PI;

            var m = (p2.Item1 + L - Θ0) / 360;
            double m0 = 0;
            double m1 = 0;
            double m2 = 0;
            if (getTransit)
            {
                m0 = m % 1;
                if (m0 < 0) m0++;

                if (!Settings.useLowPrecisionForSunTransit)
                {
                    var θ00 = Θ0 + 360.985647 * m0;
                    var n = m0 + ΔT / 86400;
                    var α = p2.Item1 + n / 2 * ((p2.Item1 - p1.Item1) + (p3.Item1 - p2.Item1) + n * (p1.Item1 - 2 * p2.Item1 + p3.Item1));
                    var H = (θ00 - L - α) % 180;
                    var Δm = -H / 360;
                    m0 += Δm;
                }
            }
            if (getRise)
            {
                m1 = (m - H0 / 360) % 1;
                if (m1 < 0) m1++;

                if (!Settings.useLowPrecisionForSunTransit)
                {
                    var θ01 = Θ0 + 360.985647 * m1;
                    var n = m1 + ΔT / 86400;
                    var α = p2.Item1 + n / 2 * ((p2.Item1 - p1.Item1) + (p3.Item1 - p2.Item1) + n * (p1.Item1 - 2 * p2.Item1 + p3.Item1));
                    var δ = (p2.Item2 + n / 2 * ((p2.Item2 - p1.Item2) + (p3.Item2 - p2.Item2) + n * (p1.Item2 - 2 * p2.Item2 + p3.Item2))) * Math.PI / 180;
                    var H = θ01 - L - α;
                    var h = Math.Asin(Math.Sin(φ) * Math.Sin(δ) + Math.Cos(φ) * Math.Cos(δ) * Math.Cos(H * Math.PI / 180)) * 180 / Math.PI;
                    var Δm = (h - h0) / (360 * Math.Cos(δ) * Math.Cos(φ) * Math.Sin(H * Math.PI / 180));
                    m1 += Δm;
                }
            }
            if (getSet)
            {
                m2 = (m + H0 / 360) % 1;
                if (m2 < 0) m2++;

                if (!Settings.useLowPrecisionForSunTransit)
                {
                    var θ02 = Θ0 + 360.985647 * m2;
                    var n = m2 + ΔT / 86400;
                    var α = p2.Item1 + n / 2 * ((p2.Item1 - p1.Item1) + (p3.Item1 - p2.Item1) + n * (p1.Item1 - 2 * p2.Item1 + p3.Item1));
                    var δ = (p2.Item2 + n / 2 * ((p2.Item2 - p1.Item2) + (p3.Item2 - p2.Item2) + n * (p1.Item2 - 2 * p2.Item2 + p3.Item2))) * Math.PI / 180;
                    var H = θ02 - L - α;
                    var h = Math.Asin(Math.Sin(φ) * Math.Sin(δ) + Math.Cos(φ) * Math.Cos(δ) * Math.Cos(H * Math.PI / 180)) * 180 / Math.PI;
                    var Δm = (h - h0) / (360 * Math.Cos(δ) * Math.Cos(φ) * Math.Sin(H * Math.PI / 180));
                    m2 += Δm;
                }
            }

            return new ValueTuple<double, double, double>(m0 + utcOffset, m1 + utcOffset, m2 + utcOffset);
        }
        public static double GetDynamicTimeDifference(double JD)
        {
            return 69;
        }
    }
}
