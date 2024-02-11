const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const artifact_path = try cacheArtifact(b, target);
    defer b.allocator.free(artifact_path);

    const lib_object_path = try std.fs.path.resolve(b.allocator, &.{ artifact_path, "lib", "libwasmtime.a" });
    defer b.allocator.free(lib_object_path);

    const lib_headers_path = try std.fs.path.resolve(b.allocator, &.{ artifact_path, "include" });
    defer b.allocator.free(lib_headers_path);

    const mod = b.addModule("wasmtime", .{
        .root_source_file = .{ .path = "src/lib.zig" },
        .link_libcpp = true,
        .target = target,
        .optimize = optimize,
    });
    mod.addObjectFile(.{ .path = lib_object_path });
    mod.addIncludePath(.{ .path = lib_headers_path });
    if (target.result.os.tag == .windows) {
        mod.addCMacro("WASM_API_EXTERN", "");
        mod.addCMacro("WASM_API_EXTERN", "");
        mod.linkSystemLibrary("ws2_32", .{});
        mod.linkSystemLibrary("advapi32", .{});
        mod.linkSystemLibrary("userenv", .{});
        mod.linkSystemLibrary("ntdll", .{});
        mod.linkSystemLibrary("shell32", .{});
        mod.linkSystemLibrary("ole32", .{});
        mod.linkSystemLibrary("bcrypt", .{});
    }
}

fn cacheArtifact(b: *std.Build, target: std.Build.ResolvedTarget) ![]const u8 {
    const cache_root = b.cache_root.path orelse ".";

    const version = "v17.0.1";

    var archive_format: []const u8 = "tar.xz";
    const target_str = switch (target.result.os.tag) {
        .linux => switch (target.result.cpu.arch) {
            .aarch64 => "aarch64-linux",
            .x86_64 => "x86_64-linux",
            else => return error.UnsupportedTarget,
        },
        .macos => switch (target.result.cpu.arch) {
            .aarch64 => "aarch64-macos",
            .x86_64 => "x86_64-macos",
            else => return error.UnsupportedTarget,
        },
        .windows => switch (target.result.cpu.arch) {
            .x86_64 => blk: {
                archive_format = "zip";
                break :blk "x86_64-mingw";
            },
            else => return error.UnsupportedTarget,
        },
        else => return error.UnsupportedTarget,
    };

    const artifact = try std.mem.join(b.allocator, "-", &.{ "wasmtime", version, target_str, "c-api" });
    defer b.allocator.free(artifact);

    const artifact_path = try std.fs.path.resolve(b.allocator, &.{ cache_root, artifact });
    errdefer b.allocator.free(artifact_path);

    blk: {
        var dir = std.fs.openDirAbsolute(artifact_path, .{}) catch |e| {
            switch (e) {
                error.FileNotFound => break :blk,
                else => return e,
            }
        };
        dir.close();
        return artifact_path;
    }

    const archived_artifact = try std.mem.join(b.allocator, ".", &.{ artifact, archive_format });
    defer b.allocator.free(archived_artifact);

    const url = try std.mem.join(b.allocator, "/", &.{
        "https://github.com/bytecodealliance/wasmtime/releases/download",
        version,
        archived_artifact,
    });
    defer b.allocator.free(url);

    const archived_artifact_path = try std.fs.path.resolve(b.allocator, &.{ cache_root, archived_artifact });
    defer b.allocator.free(archived_artifact_path);

    run(b, &.{ "curl", "-L", url, "-o", archived_artifact_path });
    if (std.mem.eql(u8, archive_format, "zip")) {
        run(b, &.{ "unzip", archived_artifact_path, "-d", cache_root });
    } else {
        run(b, &.{ "tar", "-xf", archived_artifact_path, "-C", cache_root });
    }
    try std.fs.deleteFileAbsolute(archived_artifact_path);
    return artifact_path;
}

fn run(b: *std.Build, argv: []const []const u8) void {
    const stdout = b.run(argv);
    b.allocator.free(stdout);
}
