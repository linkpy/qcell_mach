const std = @import("std");
const mach = @import("libs/mach/build.zig");


pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigimg_dep = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    const app = try mach.App.init(b, .{
        .name = "qcell",
        .src = "src/main.zig",
        .target = target,
        .deps = &[_]std.build.ModuleDependency{
            .{ .name = "zigimg", .module = zigimg_dep.module("zigimg") },
        },
        .optimize = optimize,
    });
    try app.link(.{});
    app.install();

    const run_cmd = app.addRunArtifact();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}