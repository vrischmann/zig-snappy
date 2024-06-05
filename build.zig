const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const t = target.result;

    const project_version = std.SemanticVersion{
        .major = 1,
        .minor = 2,
        .patch = 1,
    };

    const is_unix = t.os.tag == .linux or t.os.tag.isBSD() or t.os.tag.isDarwin() or t.os.tag.isSolarish();

    const config_h = b.addConfigHeader(.{
        .style = .{ .cmake = b.path("cmake/config.h.in") },
        .include_path = "config.h",
    }, .{
        .HAVE_ATTRIBUTE_ALWAYS_INLINE = 1,
        .HAVE_BUILTIN_CTZ = 1,
        .HAVE_BUILTIN_EXPECT = 1,
        .HAVE_BUILTIN_PREFETCH = 1,
        .HAVE_FUNC_MMAP = @intFromBool(is_unix),
        .HAVE_FUNC_SYSCONF = @intFromBool(t.os.tag == .linux),
        .HAVE_LIBLZO2 = 0, // TODO(vincent): find out what this is needed for
        .HAVE_LIBZ = 0, // TODO(vincent): find out what this is needed for
        .HAVE_LIBZ4 = 0, // TODO(vincent): find out what this is needed for
        .HAVE_SYS_MMAN_H = @intFromBool(is_unix),
        .HAVE_SYS_RESOURCE_H = @intFromBool(is_unix),
        .HAVE_SYS_TIME_H = @intFromBool(is_unix),
        .HAVE_SYS_UIO_H = @intFromBool(is_unix),
        .HAVE_UNISTD_H = @intFromBool(is_unix),
        .HAVE_WINDOWS_H = @intFromBool(t.os.tag == .windows),
        .SNAPPY_HAVE_SSSE3 = have_x86_feat(t, .ssse3),
        .SNAPPY_HAVE_X86_CRC32 = have_x86_feat(t, .crc32),
        .SNAPPY_HAVE_BMI2 = have_x86_feat(t, .bmi2),
        .SNAPPY_HAVE_NEON = have_arm_feat(t, .neon) | have_aarch64_feat(t, .neon),
        .SNAPPY_HAVE_NEON_CRC32 = 0,
        .SNAPPY_IS_BIG_ENDIAN = @intFromBool(t.cpu.arch.endian() == .big),
    });

    const snappy_stubs_public_h = b.addConfigHeader(.{
        .style = .{ .cmake = b.path("snappy-stubs-public.h.in") },
        .include_path = "snappy-stubs-public.h",
    }, .{
        .HAVE_SYS_UIO_H_01 = @intFromBool(is_unix),
        .PROJECT_VERSION_MAJOR = @as(i64, @intCast(project_version.major)),
        .PROJECT_VERSION_MINOR = @as(i64, @intCast(project_version.minor)),
        .PROJECT_VERSION_PATCH = @as(i64, @intCast(project_version.patch)),
    });

    const lib = b.addStaticLibrary(.{
        .name = "snappy",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(b.path("."));
    lib.linkLibCpp();
    lib.addConfigHeader(config_h);
    lib.addConfigHeader(snappy_stubs_public_h);

    lib.addCSourceFiles(.{
        .files = &all_sources,
    });

    lib.installConfigHeader(config_h);
    lib.installHeader(b.path("snappy-c.h"), "snappy-c.h");

    b.installArtifact(lib);
}

const all_sources = [_][]const u8{ "snappy.cc", "snappy-c.cc", "snappy-sinksource.cc", "snappy-stubs-internal.cc" };

fn have_x86_feat(t: std.Target, feat: std.Target.x86.Feature) c_int {
    return @intFromBool(switch (t.cpu.arch) {
        .x86, .x86_64 => std.Target.x86.featureSetHas(t.cpu.features, feat),
        else => false,
    });
}

fn have_arm_feat(t: std.Target, feat: std.Target.arm.Feature) c_int {
    return @intFromBool(switch (t.cpu.arch) {
        .arm, .armeb => std.Target.arm.featureSetHas(t.cpu.features, feat),
        else => false,
    });
}

fn have_aarch64_feat(t: std.Target, feat: std.Target.aarch64.Feature) c_int {
    return @intFromBool(switch (t.cpu.arch) {
        .aarch64,
        .aarch64_be,
        => std.Target.aarch64.featureSetHas(t.cpu.features, feat),

        else => false,
    });
}
