const std = @import("std");
const freetype = @import("libs/mach-freetype/build.zig");
const zwl_pkg = std.build.Pkg{
    .name = "zwl",
    .source = .{ .path = "libs/zwl/src/zwl.zig" },
    .dependencies = &.{
        .{
            .name = "win32",
            .source = .{ .path = "libs/zwl/libs/zigwin32/win32.zig" },
        },
    },
};

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zig-bounty", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    exe.addPackage(zwl_pkg);

    freetype.link(b, exe, .{});
    exe.addPackage(freetype.pkg(b));

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
