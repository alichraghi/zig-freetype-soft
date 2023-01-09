const std = @import("std");
const builtin = @import("builtin");
const win32 = @import("win32").everything;
const freetype = @import("freetype");
const gl = @import("gl4v3.zig");

const firasans = @embedFile("assets/firasans.ttf");
const vert_shader = @embedFile("vertex.glsl");
const frag_shader = @embedFile("frag.glsl");

const WIDTH = 800;
const HEIGHT = 640;

var chars: [128]freetype.GlyphSlot = undefined;
var vao: u32 = 0;
var vbo: u32 = 0;
var program: u32 = 0;
var memory_dc: win32.HDC = undefined;

fn windowProc(hwnd: win32.HWND, uMsg: u32, wParam: win32.WPARAM, lParam: win32.LPARAM) callconv(std.os.windows.WINAPI) win32.LRESULT {
    switch (uMsg) {
        win32.WM_DESTROY => {
            win32.PostQuitMessage(0);
            return 0;
        },
        win32.WM_PAINT => {
            var ps: win32.PAINTSTRUCT = undefined;
            const hdc = win32.BeginPaint(hwnd, &ps);
            _ = win32.BitBlt(memory_dc, 10, 10, 100, 100, hdc, 0, 0, .SRCCOPY);
            _ = win32.EndPaint(hwnd, &ps);
            return 0;
        },
        else => {},
    }

    return win32.DefWindowProcA(hwnd, uMsg, wParam, lParam);
}
const class_name = "Hello";

pub fn main() !void {
    // Create window
    const instance = @ptrCast(win32.HINSTANCE, win32.GetModuleHandleW(null) orelse unreachable);

    const wc = win32.WNDCLASSA{
        .style = win32.WNDCLASS_STYLES.initFlags(.{
            .OWNDC = 1,
            .HREDRAW = 1,
            .VREDRAW = 1,
        }),
        .lpfnWndProc = windowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = instance,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = class_name,
    };
    _ = win32.RegisterClassA(&wc);

    const hwnd = win32.CreateWindowExA(
        win32.WINDOW_EX_STYLE.initFlags(.{}),
        class_name,
        "Hello",
        win32.WINDOW_STYLE.initFlags(.{
            .THICKFRAME = 1,
            .SYSMENU = 1,
            .MINIMIZE = 1,
            .MAXIMIZE = 1,
        }),
        win32.CW_USEDEFAULT,
        win32.CW_USEDEFAULT,
        WIDTH,
        HEIGHT,
        null,
        null,
        instance,
        null,
    ) orelse unreachable;
    _ = win32.ShowWindow(hwnd, .SHOWNORMAL);

    // Load and create ASCII characters texture
    try loadCharacters();

    var bmi = std.mem.zeroes(win32.BITMAPINFO);
    bmi.bmiHeader.biSize = @sizeOf(win32.BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = 100;
    bmi.bmiHeader.biHeight = -@as(i32, 100);
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = win32.BI_RGB;
    var pixels: ?[*]u8 = null;
    const hDC = win32.GetDC(hwnd) orelse unreachable;

    memory_dc = win32.CreateCompatibleDC(hDC);
    errdefer _ = win32.DeleteDC(memory_dc);

    _ = win32.CreateDIBSection(
        hDC,
        &bmi,
        .RGB_COLORS,
        @ptrCast(*?*anyopaque, &pixels),
        null,
        0,
    ) orelse unreachable;
    _ = win32.ReleaseDC(hwnd, hDC);

    var i: usize = 0;
    while (i < 100 * 100 * 3) : (i += 3) {
        pixels.?[i] = 255;
        pixels.?[i + 1] = 0;
        pixels.?[i + 2] = 0;
    }

    // Run the message loop.
    var msg: win32.MSG = undefined;
    while (win32.GetMessageA(&msg, null, 0, 0) != 0) {
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageA(&msg);

        renderText("Hello Stephen!", -0.5, 0, 2.0 / @as(f32, WIDTH), .{ 1, 0.8, 0 });
        renderText("Hello Stephen!", -0.2, 0.2, 2.0 / @as(f32, HEIGHT), .{ 1, 0.8, 0 });

        // Limit to 60fps
        std.time.sleep(16 * std.time.ns_per_ms);
    }
}

fn renderText(text: []const u8, x: f32, y: f32, scale: f32, color: [3]f32) void {
    _ = color;
    var c_x = x;
    var c_y = y;
    for (text) |c| {
        const char = chars[c];

        // const vx = c_x + @intToFloat(f32, char.left) * scale;
        // const vy = c_y + @intToFloat(f32, char.top) * scale;
        // const w = @intToFloat(f32, char.width) * scale;
        // const h = @intToFloat(f32, char.rows) * scale;

        c_x += @intToFloat(f32, char.advance().x >> 6) * scale;
        c_y += @intToFloat(f32, char.advance().y >> 6) * scale;
    }
}

fn loadCharacters() !void {
    const ft_lib = try freetype.Library.init();
    defer ft_lib.deinit();
    const face = try ft_lib.createFaceMemory(firasans, 0);
    defer face.deinit();

    try face.setPixelSizes(0, 48);

    for (chars) |*c, i| {
        try face.loadChar(@intCast(u8, i), .{ .render = true });
        c.* = face.glyph();
    }
}
