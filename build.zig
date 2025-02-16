const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const major = 3;
    _ = major; // autofix
    const minor = 0;
    _ = minor; // autofix
    const micro = 0;
    _ = micro; // autofix

    const shared = b.option(bool, "shared", "Whether to build SDL_gpu_shadercross as a shared depenency") orelse false;
    const dxc = b.option(bool, "dxc", "Whether to build with DXC support") orelse true;
    const dxc_shared = b.option(bool, "dxc_shared", "Whether to link against DXC as a shared library") orelse false;
    const spirv_cross_shared = b.option(bool, "spirvcross_shared", "Whether to link against SPIRV-Cross as a shared library") orelse false;
    const cli = b.option(bool, "cli", "Whether to build the CLI") orelse true;

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");

    const upstream = b.dependency("SDL_shadercross", .{});
    const spirv_headers = b.dependency("SPIRV-Headers", .{});

    const name = if (shared) "SDL_shadercross-shared" else "SDL_shadercross";

    const SDL_shadercross = if (shared) b.addSharedLibrary(.{
        .name = name,
        .target = target,
        .optimize = optimize,
    }) else b.addStaticLibrary(.{
        .name = name,
        .target = target,
        .optimize = optimize,
    });
    SDL_shadercross.linkLibC();

    SDL_shadercross.linkLibrary(sdl_lib);

    const spirv_cross = b.dependency("SPIRV-Cross_zig", .{
        .target = target,
        .optimize = optimize,
        .spv_cross_reflect = true,
        .spv_cross_cpp = false,
    });
    SDL_shadercross.linkLibrary(spirv_cross.artifact(if (spirv_cross_shared) "spirv-cross-c-shared" else "spirv-cross-c"));
    SDL_shadercross.addIncludePath(spirv_headers.path("include/spirv/1.2/"));

    // If the user is requesting DXC support, get the dxcompiler dependency
    if (dxc)
        if (b.lazyDependency("mach_dxcompiler", .{
            .target = target,
            .optimize = optimize,
            .spirv = true,
            .skip_executables = true,
            .skip_tests = true,
            .from_source = true,
            .shared = dxc_shared,
        })) |dxcompiler| {
            SDL_shadercross.linkLibrary(dxcompiler.artifact("machdxcompiler"));
            SDL_shadercross.root_module.addCMacro("SDL_SHADERCROSS_DXC", "1");
        };

    SDL_shadercross.addIncludePath(upstream.path("include"));
    SDL_shadercross.addCSourceFile(.{
        .file = upstream.path("src/SDL_shadercross.c"),
        .flags = &.{
            "-std=c99",
            "-Werror",
        },
    });
    SDL_shadercross.installHeadersDirectory(upstream.path("include"), "", .{});

    b.installArtifact(SDL_shadercross);

    if (cli) {
        const exe = b.addExecutable(.{
            .name = "shadercross",
            .target = target,
            .optimize = optimize,
        });
        exe.addCSourceFile(.{ .file = upstream.path("src/cli.c") });
        exe.linkLibrary(SDL_shadercross);
        exe.linkLibrary(sdl_lib);

        b.installArtifact(exe);
    }
}
