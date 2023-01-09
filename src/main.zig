const std = @import("std");
const builtin = @import("builtin");
const freetype = @import("freetype");
const sdl = @import("sdl");

const firasans = @embedFile("assets/firasans.ttf");

const default_width = 1200;
const default_height = 480;

var renderer: *sdl.SDL_Renderer = undefined;
var ft_lib: freetype.Library = undefined;
var face: freetype.Face = undefined;

pub fn main() !void {
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_EVENTS | sdl.SDL_INIT_AUDIO) < 0)
        sdlPanic();
    defer sdl.SDL_Quit();

    var window = sdl.SDL_CreateWindow(
        "SDL2 Native Demo",
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        default_width,
        default_height,
        sdl.SDL_WINDOW_SHOWN,
    ) orelse sdlPanic();
    defer _ = sdl.SDL_DestroyWindow(window);

    renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_SOFTWARE) orelse sdlPanic();
    defer _ = sdl.SDL_DestroyRenderer(renderer);

    ft_lib = try freetype.Library.init();
    defer ft_lib.deinit();
    face = try ft_lib.createFaceMemory(firasans, 0);
    defer face.deinit();

    while (true) {
        var ev: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&ev) != 0) {
            if (ev.type == sdl.SDL_QUIT)
                return;
        }

        _ = sdl.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xff);
        _ = sdl.SDL_RenderClear(renderer);

        try drawText("gAklpq", 50, 50, sdl.SDL_Color{ .r = 255, .g = 200, .b = 0, .a = 255 });
        sdl.SDL_RenderPresent(renderer);

        _ = sdl.SDL_Delay(10);
    }
}

const SpanAdditionData = struct {
    color: sdl.SDL_Color,
    dest: sdl.SDL_Rect,
};

fn drawSpansCallback(y: c_int, count: c_int, spans: [*]const freetype.Span, user: *anyopaque) callconv(.C) void {
    const addl = @ptrCast(*SpanAdditionData, @alignCast(@alignOf(*SpanAdditionData), user));
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const x_start = addl.dest.x + spans[i].x;
        const x_end = x_start + spans[i].len;
        const line_y = addl.dest.h - y;

        _ = sdl.SDL_SetRenderDrawColor(renderer, addl.color.r, addl.color.g, addl.color.b, spans[i].coverage);
        _ = sdl.SDL_RenderDrawLine(renderer, x_start, line_y, x_end, line_y);
    }
}

fn drawText(text: []const u8, x: i32, y: i32, color: sdl.SDL_Color) !void {
    var addl = SpanAdditionData{
        .dest = .{
            .x = 0,
            .y = 0,
            .w = 0,
            .h = 0,
        },
        .color = color,
    };

    try face.setPixelSizes(0, 72);

    const rect_w = face.size().metrics().x_ppem * @intCast(c_int, text.len);
    const rect_h = face.size().metrics().y_ppem + -(face.bbox().yMin >> 6);

    const currentTarget = sdl.SDL_GetRenderTarget(renderer);
    const target = sdl.SDL_CreateTexture(renderer, sdl.SDL_PIXELFORMAT_RGBA8888, sdl.SDL_TEXTUREACCESS_TARGET, rect_w, rect_h);
    _ = sdl.SDL_SetRenderTarget(renderer, target);
    _ = sdl.SDL_SetRenderDrawBlendMode(renderer, sdl.SDL_BLENDMODE_BLEND);

    for (text) |c| {
        try face.loadChar(c, .{ .no_bitmap = true });
        const glyph = face.glyph();

        addl.dest.h = (face.size().metrics().ascender) >> 6;

        std.debug.assert(face.glyph().format() == .outline);
        var params = freetype.Raster.Params{
            .target = undefined,
            .source = undefined,
            .flags = @bitCast(c_int, freetype.Raster.Flags{ .aa = true, .direct = true }),
            .gray_spans = drawSpansCallback,
            .user = &addl,
            .clip_box = .{
                .xMin = 0,
                .yMin = 0,
                .xMax = 0,
                .yMax = 0,
            },
        };
        try ft_lib.renderOutline(face.glyph().outline() orelse unreachable, &params);

        addl.dest.x += glyph.advance().x >> 6;
    }

    var rect = sdl.SDL_Rect{
        .x = x,
        .y = y,
        .w = rect_w,
        .h = rect_h,
    };
    _ = sdl.SDL_SetRenderTarget(renderer, currentTarget);
    _ = sdl.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff);
    _ = sdl.SDL_RenderDrawRect(renderer, &rect);

    _ = sdl.SDL_SetTextureBlendMode(target, sdl.SDL_BLENDMODE_BLEND);

    _ = sdl.SDL_RenderCopyEx(renderer, target, null, &rect, 0, null, sdl.SDL_FLIP_NONE);
}

// fn loadCharacters() !void {
//     try face.setPixelSizes(0, 48);

//     for (chars) |*c, i| {
//         try face.loadChar(@intCast(u8, i), .{ .render = true });
//         c.* = .{
//             .bitmap = face.glyph().bitmap(),
//             .advance = face.glyph().advance(),
//         };
//     }
// }

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, sdl.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
