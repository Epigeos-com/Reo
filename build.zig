const std = @import("std");

pub fn build(b: *std.Build) !void {
    const standard_target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    var targets = std.ArrayList(std.Build.ResolvedTarget).init(b.allocator);
    defer targets.deinit();

    // Target options
    const TargetOptions = enum { all, pc, mobile, linux, windows, macos, android, ios };
    const CpuArchRangeOptions = enum { all, four, two };
    const target_set_option = b.option(TargetOptions, "tgts", "Build for multiple targets");
    const cpu_arch_range_option = b.option(CpuArchRangeOptions, "tgtscpu", "Specify how many of the most popular cpu archs to build for when using tgts (default: two)") orelse .two;
    const android_api_level_option = b.option(u32, "tgtsaapi", "Android API for multi-target build (default: 21)") orelse 21;
    const allow_debug_multitarget_build_option = b.option(bool, "tgtsallowdebug", "Allow tgts to run on debug optimisation mode");
    if (target_set_option) |target_set_option_| {
        if (optimize == .Debug and !(allow_debug_multitarget_build_option orelse false)) std.debug.panic("Attempted multi-target build on Debug optimiser, use -Dtgtsallowdebug to allow this", .{});
        const cpu_range = @intFromEnum(cpu_arch_range_option);
        if (target_set_option_ == .linux or target_set_option_ == .pc or target_set_option_ == .all) {
            try targets.appendSlice(&.{
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .x86_64 }),
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .x86 }),
            });
            if (cpu_range < 2) try targets.appendSlice(&.{
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .aarch64 }), // No SDL files available
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .arm }), // No SDL files available
            });
            if (cpu_range < 1) try targets.appendSlice(&.{
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .mips64 }), // No SDL files available
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .mips64el }), // No SDL files available
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .mips }), // No SDL files available
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .mipsel }), // No SDL files available
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .powerpc64 }), // No SDL files available
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .powerpc64le }), // No SDL files available
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .powerpc }), // No SDL files available
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .powerpcle }), // No SDL files available
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .s390x }), // No SDL files available
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .riscv64 }), // No SDL files available
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .gnu, .cpu_arch = .riscv32 }), // No SDL files available
            });
        }
        if (target_set_option_ == .windows or target_set_option_ == .pc or target_set_option_ == .all) {
            try targets.appendSlice(&.{
                b.resolveTargetQuery(.{ .os_tag = .windows, .cpu_arch = .x86_64 }),
                b.resolveTargetQuery(.{ .os_tag = .windows, .cpu_arch = .x86 }),
            });
            if (cpu_range < 2) try targets.appendSlice(&.{
                b.resolveTargetQuery(.{ .os_tag = .windows, .cpu_arch = .aarch64 }), // No SDL files available
                b.resolveTargetQuery(.{ .os_tag = .windows, .cpu_arch = .arm }), // No SDL files available
            });
        }
        if (target_set_option_ == .macos or target_set_option_ == .pc or target_set_option_ == .all) {
            try targets.appendSlice(&.{
                b.resolveTargetQuery(.{ .os_tag = .macos, .cpu_arch = .aarch64 }), // No SDL files available //.abi = .none
                b.resolveTargetQuery(.{ .os_tag = .macos, .cpu_arch = .x86_64 }), // No SDL files available
            });
            if (cpu_range < 2) try targets.appendSlice(&.{
                b.resolveTargetQuery(.{ .os_tag = .macos, .cpu_arch = .x86 }), // No SDL files available
                b.resolveTargetQuery(.{ .os_tag = .macos, .cpu_arch = .arm }), // No SDL files available
            });
            if (cpu_range < 1) try targets.appendSlice(&.{
                b.resolveTargetQuery(.{ .os_tag = .macos, .cpu_arch = .powerpc64 }), // No SDL files available
                b.resolveTargetQuery(.{ .os_tag = .macos, .cpu_arch = .powerpc }), // No SDL files available
            });
        }
        if (target_set_option_ == .android or target_set_option_ == .mobile or target_set_option_ == .all) {
            try targets.appendSlice(&.{
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .android, .cpu_arch = .aarch64, .android_api_level = android_api_level_option }),
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .androideabi, .cpu_arch = .arm, .android_api_level = android_api_level_option }),
            });
            if (cpu_range < 2) try targets.appendSlice(&.{
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .android, .cpu_arch = .x86_64, .android_api_level = android_api_level_option }),
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .android, .cpu_arch = .x86, .android_api_level = android_api_level_option }),
            });
            if (cpu_range < 1) try targets.appendSlice(&.{
                b.resolveTargetQuery(.{ .os_tag = .linux, .abi = .android, .cpu_arch = .riscv64, .android_api_level = 35 }),
            });
            if (cpu_range < 1 and android_api_level_option < 35) std.debug.print("Changed android api version for riscv64 to 35, as it does not support older versions\n", .{});
        }
        if (target_set_option_ == .ios or target_set_option_ == .mobile or target_set_option_ == .all) {
            try targets.appendSlice(&.{
                b.resolveTargetQuery(.{ .os_tag = .ios, .cpu_arch = .aarch64 }), // No SDL files available //.abi = .none
                b.resolveTargetQuery(.{ .os_tag = .ios, .cpu_arch = .arm }), // No SDL files available
            });
        }
    } else {
        try targets.append(standard_target);
    }
    var run_step_exe: ?*std.Build.Step.Compile = null;

    // App name
    const app_name = @tagName(@import("build.zig.zon").name);
    const app_name_upper = try std.ascii.allocUpperString(b.allocator, app_name);
    defer b.allocator.free(app_name_upper);

    // Files
    b.build_root.handle.makeDir("zig-out") catch |err| if (err == std.fs.Dir.MakeError.PathAlreadyExists) undefined else return err;
    var lib_dir = try b.build_root.handle.openDir("lib", .{ .iterate = true });
    var lib_dir_iterator = lib_dir.iterateAssumeFirstIteration();
    var libs = std.ArrayList([]const u8).init(b.allocator);
    defer libs.deinit();
    while (try lib_dir_iterator.next()) |entry| if (entry.kind == .directory) try libs.append(entry.name);
    lib_dir.close();

    for (targets.items) |target| {
        // Exe
        const exe_mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        const exe: *std.Build.Step.Compile =
            if (target.result.abi.isAndroid())
                b.addSharedLibrary(.{
                    .name = app_name_upper,
                    .root_module = exe_mod,
                })
            else
                b.addExecutable(.{
                    .name = app_name,
                    .root_module = exe_mod,
                });
        const write_files = b.addWriteFiles();
        exe.step.dependOn(&write_files.step);
        if (target.result.cpu.arch == standard_target.result.cpu.arch and target.result.os.tag == standard_target.result.os.tag and target.result.abi == standard_target.result.abi) run_step_exe = exe;

        // Files
        const os_string = try std.fmt.allocPrint(b.allocator, "{s}-{s}-{s}", .{ @tagName(target.result.cpu.arch), @tagName(target.result.os.tag), @tagName(target.result.abi) });
        // defer b.allocator.free(os_string); // The build uses this and freeing this causes a corrupted output
        const target_dir_path = try std.fmt.allocPrint(b.allocator, "zig-out/{s}", .{os_string});
        defer b.allocator.free(target_dir_path);
        b.build_root.handle.makeDir(target_dir_path) catch |err| if (err == std.fs.Dir.MakeError.PathAlreadyExists) undefined else return err;
        var target_dir = try b.build_root.handle.openDir(target_dir_path, .{});
        defer target_dir.close();

        // LibC // TODO: Linux-specific
        if (target.result.abi.isAndroid()) {
            const android_os_string = try std.mem.replaceOwned(u8, b.allocator, os_string, "x86-", "i686-");
            const libc_conf_content = try std.fmt.allocPrint(b.allocator,
                \\include_dir=/usr/include/
                \\sys_include_dir=/usr/include
            ++ "\ncrt_dir=/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/{s}/{d}\n" ++
                \\msvc_lib_dir=
                \\kernel32_lib_dir=
                \\gcc_dir=
            , .{ android_os_string, target.result.os.version_range.linux.android });
            defer b.allocator.free(libc_conf_content);
            const libc_conf = write_files.add("libc.conf", libc_conf_content);
            exe.libc_file = libc_conf;

            const libcpp_shared_path = try std.fmt.allocPrint(b.allocator, "/opt/android-sdk/ndk-bundle/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/{s}/libc++_shared.so", .{android_os_string});
            try target_dir.symLink(libcpp_shared_path, "libc++_shared.so", .{});
            b.allocator.free(android_os_string);
        }
        exe.linkLibC();

        // Libs
        const needs_separate_libs = target.result.os.tag == .windows or target.result.abi.isAndroid();
        const lib_prefix = if (target.result.os.tag == .windows) "" else "lib";
        const lib_extension = if (target.result.os.tag == .windows) "dll" else "so";
        for (libs.items) |lib| {
            const lib_src_file_path = try std.fmt.allocPrint(b.allocator, "lib/{s}/{s}.{s}", .{ lib, os_string, lib_extension });
            const lib_dest_file_name = try std.fmt.allocPrint(b.allocator, "{s}{s}.{s}", .{ lib_prefix, lib, lib_extension });
            if (needs_separate_libs) b.build_root.handle.copyFile(lib_src_file_path, target_dir, lib_dest_file_name, .{}) catch |err| std.debug.panic("{}, lib_src_file_path: {s}\n", .{ err, lib_src_file_path }) else _ = write_files.addCopyFile(b.path(lib_src_file_path), lib_dest_file_name);
            // b.allocator.free(lib_src_file_path); // The build uses this and freeing this causes a corrupted output
            b.allocator.free(lib_dest_file_name);
            exe.linkSystemLibrary(lib);
        }

        // Links
        if (target.result.os.tag == .windows) exe.subsystem = .Windows;
        exe.addIncludePath(b.path("include/"));
        exe.addLibraryPath(if (needs_separate_libs) b.path(target_dir_path) else write_files.getDirectory());
        const artifact = b.addInstallArtifact(exe, .{ .dest_dir = .{ .override = .{ .custom = os_string } } });
        b.getInstallStep().dependOn(&artifact.step);
    }

    if (run_step_exe) |run_step_exe_| {
        const run_cmd = b.addRunArtifact(run_step_exe_);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_cmd.addArgs(args);
        const run_step = b.step("run", "Run the app, requires your current setup as one of the targets");
        run_step.dependOn(&run_cmd.step);
    }
}
