const std = @import("std");
const freetype = @import("libs/mach-freetype/build.zig");
const sdl = @import("libs/SDL.zig/Sdk.zig");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zig-bounty", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    var sdk = sdl.init(b);
    exe.addPackage(sdk.getNativePackage("sdl"));
    sdk.link(exe, .static);

    freetype.link(b, exe, .{});
    exe.addPackage(freetype.pkg(b));
    exe.addPackage(freetype.harfbuzz_pkg(b));

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
