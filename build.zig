const std = @import("std");

pub fn build(b: *std.Build) void {
    const os_string = "linux"; // This is used only in getting the right SDL3 file, by convention of this repo, it's the same as .os_tag except for android, where it's "android" instead
    const cpu_arch_string = "x86_64"; // This should be the same as .cpu_arch
    // const target = b.standardTargetOptions(.{ .default_target = .{ .os_tag = .windows, .cpu_arch = .x86_64 } });
    const target = b.standardTargetOptions(.{ .default_target = .{ .os_tag = .linux, .cpu_arch = .x86_64, .abi = .gnu } });
    // const target = b.standardTargetOptions(.{ .default_target = .{ .abi = .android, .android_api_level = 21, .cpu_arch = .aarch64 } });
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe: *std.Build.Step.Compile =
        if (target.result.abi.isAndroid())
            b.addSharedLibrary(.{
                .name = "REO",
                .root_module = exe_mod,
            })
        else
            b.addExecutable(.{
                .name = "Reo",
                .root_module = exe_mod,
            });

    const write_files = b.addWriteFiles();
    if (target.result.abi == .android) {
        const libc_conf_content = std.fmt.allocPrint(b.allocator,
            \\include_dir=/usr/include/
            \\sys_include_dir=/usr/include
        ++ "\ncrt_dir=/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/{s}-linux-android/{d}\n" ++
            \\msvc_lib_dir=
            \\kernel32_lib_dir=
            \\gcc_dir=
        , .{ cpu_arch_string, target.result.os.version_range.linux.android }) catch @panic("AllocPrintError");
        defer b.allocator.free(libc_conf_content);
        const libc_conf = write_files.add("libc.conf", libc_conf_content);
        exe.libc_file = libc_conf;
    }

    b.exe_dir = "out/";
    b.lib_dir = "out/";
    var libPath: std.Build.LazyPath = undefined;
    if (target.result.os.tag == .windows) {
        exe.subsystem = .Windows;
        libPath = write_files.addCopyFile(b.path("lib/SDL3/windows-" ++ cpu_arch_string ++ ".dll"), "../../../out/SDL3.dll");
        _ = write_files.addCopyFile(b.path("lib/SDL3_ttf/windows-" ++ cpu_arch_string ++ ".dll"), "../../../out/SDL3_ttf.dll");
    } else {
        if (target.result.abi == .android) {
            libPath = write_files.addCopyFile(b.path("lib/SDL3/android-" ++ cpu_arch_string ++ ".so"), "../../../out/libSDL3.so");
            _ = write_files.addCopyFile(b.path("lib/SDL3_ttf/android-" ++ cpu_arch_string ++ ".so"), "../../../out/libSDL3_ttf.so");
        } else {
            libPath = write_files.addCopyFile(b.path("lib/SDL3/" ++ os_string ++ "-" ++ cpu_arch_string ++ ".so"), "libSDL3.so");
            _ = write_files.addCopyFile(b.path("lib/SDL3_ttf/" ++ os_string ++ "-" ++ cpu_arch_string ++ ".so"), "libSDL3_ttf.so");
        }
    }

    exe.linkLibC();
    exe.addIncludePath(b.path("include/"));
    exe.addLibraryPath(libPath.dirname());
    exe.linkSystemLibrary("SDL3");
    exe.linkSystemLibrary("SDL3_ttf");

    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
