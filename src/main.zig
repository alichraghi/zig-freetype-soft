const std = @import("std");
const freetype = @import("freetype");
const sdl = @import("sdl");

const firasans = @embedFile("assets/firasans.ttf");
const default_width = 1200;
const default_height = 480;

var renderer: *sdl.SDL_Renderer = undefined;
var ft_lib: freetype.Library = undefined;
var face: freetype.Face = undefined;

pub fn main() !void {
    // Create window
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_EVENTS) < 0)
        unreachable;
    defer sdl.SDL_Quit();

    var window = sdl.SDL_CreateWindow(
        "SDL2 + Freetype",
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        default_width,
        default_height,
        sdl.SDL_WINDOW_SHOWN,
    ) orelse unreachable;
    defer _ = sdl.SDL_DestroyWindow(window);

    renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_SOFTWARE) orelse unreachable;
    defer _ = sdl.SDL_DestroyRenderer(renderer);

    // Initialize freetype
    ft_lib = try freetype.Library.init();
    defer ft_lib.deinit();
    face = try ft_lib.createFaceMemory(firasans, 0);
    defer face.deinit();

    try face.setPixelSizes(0, 72);

    // Main loop
    while (true) {
        var ev: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&ev) != 0) {
            if (ev.type == sdl.SDL_QUIT) return;
        }

        _ = sdl.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xff);
        _ = sdl.SDL_RenderClear(renderer);

        try drawText("Hello Ziguanas!", 50, 50, sdl.SDL_Color{ .r = 255, .g = 200, .b = 0, .a = 255 });

        sdl.SDL_RenderPresent(renderer);
        _ = sdl.SDL_Delay(16); // limit to 60fps
    }
}

const GlyphData = struct {
    color: sdl.SDL_Color,
    x: i32,
    y: i32,
};

fn drawText(text: []const u8, x: i32, y: i32, color: sdl.SDL_Color) !void {
    var glyph_data = GlyphData{
        .x = x,
        .y = y,
        .color = color,
    };

    var raster_params = freetype.Raster.Params{
        .target = undefined,
        .source = undefined,
        .flags = @bitCast(c_int, freetype.Raster.Flags{ .aa = true, .direct = true }),
        .gray_spans = drawSpansCallback,
        .user = &glyph_data,
        .clip_box = .{ .xMin = 0, .yMin = 0, .xMax = 0, .yMax = 0 },
    };

    _ = sdl.SDL_SetRenderDrawBlendMode(renderer, sdl.SDL_BLENDMODE_BLEND);
    for (text) |c| {
        try face.loadChar(c, .{ .no_bitmap = true });
        try ft_lib.renderOutline(face.glyph().outline() orelse unreachable, &raster_params);
        glyph_data.x += face.glyph().advance().x >> 6;
    }
}

fn drawSpansCallback(y: c_int, count: c_int, spans: [*]const freetype.Span, user: *anyopaque) callconv(.C) void {
    const glyph_data = @ptrCast(*GlyphData, @alignCast(@alignOf(*GlyphData), user));

    for (spans[0..@intCast(usize, count)]) |span| {
        const x_start = glyph_data.x + span.x;
        const x_end = x_start + span.len;
        const line_y = ((face.size().metrics().ascender + face.bbox().yMin) >> 6) + glyph_data.y - y;

        _ = sdl.SDL_SetRenderDrawColor(renderer, glyph_data.color.r, glyph_data.color.g, glyph_data.color.b, span.coverage);
        _ = sdl.SDL_RenderDrawLine(renderer, x_start, line_y, x_end, line_y);
    }
}
