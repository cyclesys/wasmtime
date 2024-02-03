const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const artifact_path = try cacheArtifact(b, switch (target.result.os.tag) {
        .linux => "x86_64-linux",
        else => @panic("unsupported os"),
    });
    defer b.allocator.free(artifact_path);

    const lib_object_path = try std.fs.path.resolve(b.allocator, &.{ artifact_path, "lib", "libwasmtime.a" });
    defer b.allocator.free(lib_object_path);

    const lib_headers_path = try std.fs.path.resolve(b.allocator, &.{ artifact_path, "include" });
    defer b.allocator.free(lib_headers_path);

    const lib = b.addStaticLibrary(.{
        .name = "wasmtime",
        .target = target,
        .optimize = optimize,
    });
    lib.addObjectFile(.{ .path = lib_object_path });
    lib.installHeadersDirectory(lib_headers_path, "wasmtime");
    b.installArtifact(lib);
}

fn cacheArtifact(b: *std.Build, target: []const u8) ![]const u8 {
    const cache_root = b.cache_root.path orelse ".";

    const version = "v17.0.0";
    const artifact = try std.mem.join(b.allocator, "-", &.{ "wasmtime", version, target, "c-api" });
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

    const tar_artifact = try std.mem.join(b.allocator, ".", &.{ artifact, "tar", "xz" });
    defer b.allocator.free(tar_artifact);

    const url = try std.mem.join(b.allocator, "/", &.{
        "https://github.com/bytecodealliance/wasmtime/releases/download",
        version,
        tar_artifact,
    });
    defer b.allocator.free(url);

    const tar_artifact_path = try std.fs.path.resolve(b.allocator, &.{ cache_root, tar_artifact });
    defer b.allocator.free(tar_artifact_path);

    run(b, &.{ "curl", "-L", url, "-o", tar_artifact_path });
    run(b, &.{ "tar", "-xf", tar_artifact_path, "-C", cache_root });
    run(b, &.{ "rm", tar_artifact_path });
    return artifact_path;
}

fn run(b: *std.Build, argv: []const []const u8) void {
    const stdout = b.run(argv);
    b.allocator.free(stdout);
}
