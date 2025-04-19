const std = @import("std");
const math = std.math;
const dates = @import("dates.zig");
const settings = @import("settings.zig");

// k is which moon phase it is from the new moon of 6 Jan 2000 plus 0 for new moon, .25 for first quarter, .5 for full moon, .75 for last quarter
pub fn getDateForMoonPhase(k: f32) !f64 {
    // Chapter 49, pdf page 357

    const k64: f64 = @floatCast(k);
    const T = k64 / 1236.85;
    var jdE = 2451550.09766 + 29.530588861 * k64 + 0.00015437 * T * T - 0.00000015 * T * T * T + 0.00000000073 * T * T * T * T;

    const E = 1 - 0.002516 * T - 0.0000074 * T * T;
    const M = (2.5534 + 29.10535670 * k64 - 0.0000014 * T * T - 0.00000011 * T * T * T) * math.pi / 180;
    const Mp = (201.5643 + 385.81693528 * k64 + 0.0107582 * T * T + 0.00001238 * T * T * T - 0.000000058 * T * T * T * T) * math.pi / 180;
    const F = (160.7108 + 390.67050284 * k64 - 0.0016118 * T * T - 0.00000227 * T * T * T + 0.000000011 * T * T * T * T) * math.pi / 180;
    const Omega = (124.7746 - 1.56375588 * k64 + 0.0020672 * T * T + 0.00000215 * T * T * T) * math.pi / 180;

    const A1 = (299.77 + 0.107408 * k64 - 0.009173 * T * T) * math.pi / 180;
    const A2 = (251.88 + 0.016321 * k64) * math.pi / 180;
    const A3 = (251.83 + 26.651886 * k64) * math.pi / 180;
    const A4 = (349.42 + 36.412478 * k64) * math.pi / 180;
    const A5 = (84.66 + 18.206239 * k64) * math.pi / 180;
    const A6 = (141.74 + 53.303771 * k64) * math.pi / 180;
    const A7 = (207.14 + 2.453732 * k64) * math.pi / 180;
    const A8 = (154.84 + 7.306860 * k64) * math.pi / 180;
    const A9 = (34.52 + 27.261239 * k64) * math.pi / 180;
    const A10 = (207.19 + 0.121824 * k64) * math.pi / 180;
    const A11 = (291.34 + 1.844379 * k64) * math.pi / 180;
    const A12 = (161.72 + 24.198154 * k64) * math.pi / 180;
    const A13 = (239.56 + 25.513099 * k64) * math.pi / 180;
    const A14 = (331.55 + 3.592518 * k64) * math.pi / 180;

    const kDif = k64 - math.floor(k64);
    if (kDif == 0) {
        jdE += -0.4072 * @sin(Mp) + 0.17241 * E * @sin(M) + 0.01608 * @sin(2 * Mp) + 0.01039 * @sin(2 * F) + 0.00739 * E * @sin(Mp - M) - 0.00514 * E * @sin(Mp + M) + 0.00208 * E * E * @sin(2 * M) - 0.00111 * @sin(Mp - 2 * F) - 0.00057 * @sin(Mp + 2 * F) + 0.00056 * E * @sin(2 * Mp + M) - 0.00042 * @sin(3 * Mp) + 0.00042 * E * @sin(M + 2 * F) + 0.00038 * E * @sin(M - 2 * F) - 0.00024 * E * @sin(2 * Mp - M) - 0.00017 * @sin(Omega) - 0.00007 * @sin(Mp + 2 * M) + 0.00004 * @sin(2 * Mp - 2 * F) + 0.00004 * @sin(3 * M) + 0.00003 * @sin(Mp + M - 2 * F) + 0.00003 * @sin(2 * Mp + 2 * F) - 0.00003 * @sin(Mp + M + 2 * F) + 0.00003 * @sin(Mp - M + 2 * F) - 0.00002 * @sin(Mp - M - 2 * F) - 0.00002 * @sin(3 * Mp + M) + 0.00002 * @sin(4 * Mp);
    } else if (kDif == 0.5) {
        jdE += -0.40614 * @sin(Mp) + 0.17302 * E * @sin(M) + 0.01614 * @sin(2 * Mp) + 0.01043 * @sin(2 * F) + 0.00734 * E * @sin(Mp - M) - 0.00515 * E * @sin(Mp + M) + 0.00209 * E * E * @sin(2 * M) - 0.00111 * @sin(Mp - 2 * F) - 0.00057 * @sin(Mp + 2 * F) + 0.00056 * E * @sin(2 * Mp + M) - 0.00042 * @sin(3 * Mp) + 0.00042 * E * @sin(M + 2 * F) + 0.00038 * E * @sin(M - 2 * F) - 0.00024 * E * @sin(2 * Mp - M) - 0.00017 * @sin(Omega) - 0.00007 * @sin(Mp + 2 * M) + 0.00004 * @sin(2 * Mp - 2 * F) + 0.00004 * @sin(3 * M) + 0.00003 * @sin(Mp + M - 2 * F) + 0.00003 * @sin(2 * Mp + 2 * F) - 0.00003 * @sin(Mp + M + 2 * F) + 0.00003 * @sin(Mp - M + 2 * F) - 0.00002 * @sin(Mp - M - 2 * F) - 0.00002 * @sin(3 * Mp + M) + 0.00002 * @sin(4 * Mp);
    } else if (kDif == 0.25 or kDif == 0.75) {
        jdE += -0.62801 * @sin(Mp) + 0.17172 * E * @sin(M) - 0.01183 * E * @sin(Mp + M) + 0.00862 * @sin(2 * Mp) + 0.00804 * @sin(2 * F) + 0.00454 * E * @sin(Mp - M) + 0.00204 * E * E * @sin(2 * M) - 0.0018 * @sin(Mp - 2 * F) - 0.0007 * @sin(Mp + 2 * F) - 0.0004 * @sin(3 * Mp) - 0.00034 * E * @sin(2 * Mp - M) + 0.00032 * E * @sin(M + 2 * F) + 0.00032 * E * @sin(M - 2 * F) - 0.00028 * E * E * @sin(Mp + 2 * M) + 0.00027 * E * @sin(2 * Mp + M) - 0.00017 * @sin(Omega) - 0.00005 * @sin(Mp - M - 2 * F) + 0.00004 * @sin(2 * Mp + 2 * F) - 0.00004 * @sin(Mp + M + 2 * F) + 0.00004 * @sin(Mp - 2 * M) + 0.00003 * @sin(Mp + M - 2 * F) + 0.00003 * @sin(3 * M) + 0.00002 * @sin(2 * Mp - 2 * F) + 0.00002 * @sin(Mp - M + 2 * F) - 0.00002 * @sin(3 * Mp + M);
        const W = 0.00306 - 0.00038 * E * @cos(M) + 0.00026 * @cos(Mp) - 0.00002 * @cos(Mp - M) + 0.00002 * @cos(Mp + M) + 0.00002 * @cos(2 * F);
        if (kDif == 0.25) jdE += W else jdE -= W;
    } else {
        return error.InvalidPhase;
    }

    jdE += (325 * @sin(A1) + 165 * @sin(A2) + 164 * @sin(A3) + 126 * @sin(A4) + 110 * @sin(A5) + 62 * @sin(A6) + 60 * @sin(A7) + 56 * @sin(A8) + 47 * @sin(A9) + 42 * @sin(A10) + 40 * @sin(A11) + 37 * @sin(A12) + 35 * @sin(A13) + 23 * @sin(A14)) / 1000000;
    return jdE;
}
// This is solstices and equinoxes, phase is 0 for March equinox, 1 for June solstice, 2 for September equinox, 3 for December solstice
pub fn getDateForSunPhase(year: i32, phase: u8) !f64 {
    // Chapter 27, pdf page 185

    const Y: f64 = (@as(f64, @floatFromInt(year)) - 2000) / 1000;
    const jdE0: f64 = switch (phase) {
        0 => 2451623.80984 + 365242.37404 * Y + 0.05169 * Y * Y - 0.00411 * Y * Y * Y - 0.00057 * Y * Y * Y * Y,
        1 => 2451716.56767 + 365241.62603 * Y + 0.00325 * Y * Y + 0.00888 * Y * Y * Y - 0.00030 * Y * Y * Y * Y,
        2 => 2451810.21715 + 365242.01767 * Y - 0.11575 * Y * Y + 0.00337 * Y * Y * Y + 0.00078 * Y * Y * Y * Y,
        3 => 2451900.05952 + 365242.74049 * Y - 0.06223 * Y * Y - 0.00823 * Y * Y * Y + 0.00032 * Y * Y * Y * Y,
        else => return error.InvalidPhase,
    };
    const T = (jdE0 - 2451545) / 36525;
    const W = 35999.373 * T - 2.47;
    const Deltalambda = 1 + 0.0334 * @cos(W * math.pi / 180) + 0.0007 * @cos(W * math.pi / 90);
    const S = 485 * @cos((324.96 + 1934.136 * T) * math.pi / 180) + 45 * @cos((247.54 + 29929.562 * T) * math.pi / 180) + 203 * @cos((337.23 + 32964.467 * T) * math.pi / 180) + 44 * @cos((325.15 + 31555.956 * T) * math.pi / 180) + 199 * @cos((342.08 + 20.186 * T) * math.pi / 180) + 29 * @cos((60.93 + 4443.417 * T) * math.pi / 180) + 182 * @cos((27.85 + 445267.112 * T) * math.pi / 180) + 18 * @cos((155.12 + 67555.328 * T) * math.pi / 180) + 156 * @cos((73.14 + 45036.886 * T) * math.pi / 180) + 17 * @cos((288.79 + 4562.452 * T) * math.pi / 180) + 136 * @cos((171.52 + 22518.443 * T) * math.pi / 180) + 16 * @cos((198.04 + 62894.029 * T) * math.pi / 180) + 77 * @cos((222.54 + 65928.934 * T) * math.pi / 180) + 14 * @cos((199.76 + 31436.921 * T) * math.pi / 180) + 74 * @cos((296.72 + 3034.906 * T) * math.pi / 180) + 12 * @cos((95.39 + 14577.848 * T) * math.pi / 180) + 70 * @cos((243.58 + 9037.513 * T) * math.pi / 180) + 12 * @cos((287.11 + 31931.756 * T) * math.pi / 180) + 58 * @cos((119.81 + 33718.147 * T) * math.pi / 180) + 12 * @cos((320.81 + 34777.259 * T) * math.pi / 180) + 52 * @cos((297.17 + 150.678 * T) * math.pi / 180) + 9 * @cos((227.73 + 1222.114 * T) * math.pi / 180) + 50 * @cos((21.02 + 2281.226 * T) * math.pi / 180) + 8 * @cos((15.45 + 16859.074 * T) * math.pi / 180);
    const jd = jdE0 + (0.00001 * S) / Deltalambda;
    return jd;
}
// 0 - New, 1 - First quarter, 2 - Full, 3 - Last quarter
pub fn getClosestMoonPhase(jd: f64, is_forward: bool, phase: u8) !(struct {
    jd: f64,
    k: f32,
}) {
    const frac_phase = @as(f32, @floatFromInt(phase)) / 4;

    const date = dates.jdToGregorian(jd);
    var k = @as(f32, @floatFromInt(date.year - 2000)) * 12.3685 + @as(f32, @floatFromInt(date.month));
    k = math.round(k);
    k += frac_phase;

    const moons = [5]f64{ try getDateForMoonPhase(k), try getDateForMoonPhase(k - 1), try getDateForMoonPhase(k + 1), try getDateForMoonPhase(k - 2), try getDateForMoonPhase(k + 2) };

    var moon: f64 = -1;
    var final_i: usize = undefined;
    for (moons, 0..) |element, i| {
        // moon = moons.Where(element => isForward ? (element >= dateTime) : (element <= dateTime)).OrderBy(element => Math.Max((element - dateTime).TotalDays, (dateTime - element).TotalDays)).First();
        //isForward ? (element >= dateTime) : (element <= dateTime)
        const does_element_fit = if (is_forward) (element >= jd) else (element <= jd);
        if (does_element_fit) {
            const is_element_closer_than_prev = if (moon == -1) true else (@abs(jd - moon) - @abs(jd - element) > 0);
            if (is_element_closer_than_prev) {
                moon = element;
                final_i = i;
            }
        }
    }
    const final_k = switch (final_i) {
        0 => k,
        1 => k - 1,
        2 => k + 1,
        3 => k - 2,
        else => k + 2,
    };
    return .{ .jd = moon, .k = final_k };
}
pub fn getClosestSunPhase(jd: f64, is_forward: bool, phase: u8) !(struct {
    jd: f64,
    year: i32,
}) {
    const date = dates.jdToGregorian(jd);
    const suns = [3]f64{ try getDateForSunPhase(date.year, phase), try getDateForSunPhase(date.year - 1, phase), try getDateForSunPhase(date.year + 1, phase) };

    var sun: f64 = -1;
    var final_i: usize = undefined;
    for (suns, 0..) |element, i| {
        const does_element_fit = if (is_forward) (element >= jd) else (element <= jd);
        if (does_element_fit) {
            const is_element_closer_than_prev = if (sun == -1) true else (@abs(jd - sun) - @abs(jd - element) > 0);
            if (is_element_closer_than_prev) {
                sun = element;
                final_i = i;
            }
        }
    }
    const final_year = switch (final_i) {
        0 => date.year,
        1 => date.year - 1,
        else => date.year + 1,
    };
    return .{ .jd = sun, .year = final_year };
}

// (Δψ, ε) in '' (arcsec)
pub fn getNutationValues(jd: f64) [2]f64 {
    // Chapter 22, pdf page 152

    const T = (jd - 2451545) / 36525;
    const Omega = (125.04452 - 1934.136261 * T) * math.pi / 180;
    const L = (280.4665 + 36000.7698 * T) * math.pi / 180;
    const Lp = (218.3165 + 481267.8813 * T) * math.pi / 180;

    var Deltapsi = -17.2 * @sin(Omega) - 1.32 * @sin(2 * L) - 0.23 * @sin(2 * Lp) + 0.21 * @sin(2 * Omega);
    Deltapsi = @rem(Deltapsi, 1296000);
    const Deltaepsilon = 9.2 * @cos(Omega) + 0.57 * @cos(2 * L) + 0.1 * @cos(2 * Lp) - 0.09 * @cos(2 * Omega);

    const U = T / 100;
    const epsilon0 = if (settings.use_low_precision_for_nutation_epsilon0) 84381.448 - 46.8150 * T - 0.00059 * T * T + 0.001813 * T * T * T else 84381.448 - 4680.93 * U - 1.55 * U * U + 1999.25 * U * U * U - 51.38 * U * U * U * U - 249.67 * U * U * U * U * U - 39.05 * U * U * U * U * U * U + 7.12 * U * U * U * U * U * U * U + 27.87 * U * U * U * U * U * U * U * U + 5.79 * U * U * U * U * U * U * U * U * U + 2.45 * U * U * U * U * U * U * U * U * U * U;

    const epsilon = epsilon0 + Deltaepsilon;

    return [2]f64{ Deltapsi, epsilon };
}
// In s (sec)
pub fn getApparentSiderealTimeAtGreenwich(jd: f64) f64 {
    // Chapter 12, pdf page 95

    const jd1 = math.floor(jd - 0.5) + 0.5;
    const T = (jd1 - 2451545) / 36525;

    var Theta0 = @rem((24110.54841 + 8640184.812866 * T + 0.093104 * T * T - 0.0000062 * T * T * T), 24 * 60 * 60);
    if (Theta0 < 0) Theta0 += 24 * 60 * 60;
    const theta0 = (jd1 - jd) * 1.00273790935 + Theta0;

    const nutation = getNutationValues(jd1); // ''
    // std.debug.print("nutation: {d}\n", .{nutation});
    // std.debug.print("Theta0: {s}\n", .{dates.jdToGregorian(jd1 + (Theta0 / (24 * 60 * 60)))});
    const theta = theta0 + (nutation[0] * @cos(nutation[1] * 60 * 60 * math.pi / 180)) / 15;
    // std.debug.print("theta: {s}\n", .{dates.jdToGregorian(jd1 + (theta / (24 * 60 * 60)))});
    return theta;
}
// apparent (ascension, declination), both in °
pub fn getPositionOfTheSun(jd: f64) [2]f64 {
    // Chapter 25, pdf page 171
    // Low accuracy method

    const T = (jd - 2451545) / 36525;
    const L0 = 280.46646 + 36000.76983 * T + 0.0003032 * T * T;
    const M = (357.52911 + 35999.05029 * T - 0.0001537 * T * T) * math.pi / 180;
    const C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * @sin(M) + (0.019993 - 0.000101 * T) * @sin(2 * M) + 0.000289 * @sin(3 * M);

    const O = L0 + C;
    const Omega = (125.04 - 1934.136 * T) * math.pi / 180;
    const lambda = (O - 0.00569 - 0.00478 * @sin(Omega)) * math.pi / 180;

    const epsilon = ((getNutationValues(jd)[1] / (60 * 60)) + 0.00256 * @cos(Omega)) * math.pi / 180;

    const alpha = math.atan2(@cos(epsilon) * @sin(lambda), @cos(lambda)) / math.pi * 180;
    const delta = math.asin(@sin(epsilon) * @sin(lambda)) / math.pi * 180;

    return [2]f64{ alpha, delta };
}
// In d (day)
pub fn getTimeOfSunTransitRiseSet(jd: f64, get_transit: bool, get_rise: bool, get_set: bool) [3]f64 { // TODO: Make this work
    // Chapter 15, pdf page 109

    const jd05 = math.floor(jd - 0.5) + 0.5;
    const utc_offset = 0 / 24;

    const L = -settings.longitude;
    const phi = settings.latitude * math.pi / 180;

    const DeltaT = getDynamicTimeDifference(jd05);
    const Theta0 = getApparentSiderealTimeAtGreenwich(jd05) * 15 / (60 * 60);

    const p1 = getPositionOfTheSun(jd05 - 1);
    const p2 = getPositionOfTheSun(jd05);
    const p3 = getPositionOfTheSun(jd05 + 1);
    // std.debug.print("jd05: {d}\n", .{jd05}); // right
    // std.debug.print("ΔT: {d}\n", .{DeltaT}); // assumed

    // std.debug.print("Apparent sidereal time at greenwich: {d}\n", .{Theta0 / 15}); // close, but the difference due to nutation is tiny, so might not be visible and the difference seems higher where nutation values are more wrong

    // std.debug.print("p1: {d}\n", .{p1});
    // std.debug.print("p2: {d}\n", .{p2}); // close
    // std.debug.print("p3: {d}\n", .{p3});

    const h0 = -0.8333;

    const A = (@sin(h0 * math.pi / @as(comptime_float, 180)) - @sin(phi) * @sin(p2[1] * math.pi / 180)) / (@cos(phi) * @cos(p2[1] * math.pi / 180));
    if (A < -1 or A > 1) return [3]f64{ undefined, undefined, undefined }; // Always above horizon
    const H0 = math.acos(A) * 180 / math.pi;

    const m = (p2[0] + L - Theta0) / 360;
    var m0: f64 = 0;
    var m1: f64 = 0;
    var m2: f64 = 0;
    if (get_transit) {
        m0 = @rem(m, 1);
        if (m0 < 0) m0 += 1;

        if (!settings.use_low_precision_for_sun_transit) {
            const theta00 = Theta0 + 360.985647 * m0;
            const n = m0 + DeltaT / 86400;
            const alpha = p2[0] + n / 2 * ((p2[0] - p1[0]) + (p3[0] - p2[0]) + n * (p1[0] - 2 * p2[0] + p3[0]));
            const H = @rem((theta00 - L - alpha), 180);
            const Deltam = -H / 360;
            m0 += Deltam;
        }
    }
    if (get_rise) {
        m1 = @rem((m - H0 / 360), 1);
        if (m1 < 0) m1 += 1;

        if (!settings.use_low_precision_for_sun_transit) {
            const theta01 = Theta0 + 360.985647 * m1;
            const n = m1 + DeltaT / 86400;
            const alpha = p2[0] + n / 2 * ((p2[0] - p1[0]) + (p3[0] - p2[0]) + n * (p1[0] - 2 * p2[0] + p3[0]));
            const delta = (p2[1] + n / 2 * ((p2[1] - p1[1]) + (p3[1] - p2[1]) + n * (p1[1] - 2 * p2[1] + p3[1]))) * math.pi / 180;
            const H = theta01 - L - alpha;
            const h = math.asin(@sin(phi) * @sin(delta) + @cos(phi) * @cos(delta) * @cos(H * math.pi / 180)) * 180 / math.pi;
            const Deltam = (h - h0) / (360 * @cos(delta) * @cos(phi) * @sin(H * math.pi / 180));
            m1 += Deltam;
        }
    }
    if (get_set) {
        m2 = @rem((m + H0 / 360), 1);
        if (m2 < 0) m2 += 1;

        if (!settings.use_low_precision_for_sun_transit) {
            const theta02 = Theta0 + 360.985647 * m2;
            const n = m2 + DeltaT / 86400;
            const alpha = p2[0] + n / 2 * ((p2[0] - p1[0]) + (p3[0] - p2[0]) + n * (p1[0] - 2 * p2[0] + p3[0]));
            const delta = (p2[1] + n / 2 * ((p2[1] - p1[1]) + (p3[1] - p2[1]) + n * (p1[1] - 2 * p2[1] + p3[1]))) * math.pi / 180;
            const H = theta02 - L - alpha;
            const h = math.asin(@sin(phi) * @sin(delta) + @cos(phi) * @cos(delta) * @cos(H * math.pi / 180)) * 180 / math.pi;
            const Deltam = (h - h0) / (360 * @cos(delta) * @cos(phi) * @sin(H * math.pi / 180));
            m2 += Deltam;
        }
    }

    return [3]f64{ m0 + utc_offset, m1 + utc_offset, m2 + utc_offset };
}
pub fn getDynamicTimeDifference(jd: f64) f64 {
    _ = jd;
    return 80; // TODO
}
