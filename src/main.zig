const std = @import("std");
const glfw = @import("glfw");
const freetype = @import("freetype");
const gl = @import("gl4v3.zig");

const firasans = @embedFile("assets/firasans.ttf");
const vert_shader = @embedFile("vertex.glsl");
const frag_shader = @embedFile("frag.glsl");

const WIDTH = 800;
const HEIGHT = 640;

var chars: [128]Character = undefined;
var vao: u32 = 0;
var vbo: u32 = 0;
var program: u32 = 0;

const Character = struct {
    id: u32,
    width: u32,
    rows: u32,
    left: i32,
    top: i32,
    advance: freetype.Vector,
};

pub fn main() !void {
    // Create window
    try glfw.init(.{});
    defer glfw.terminate();

    const window_hints = glfw.Window.Hints{
        .context_version_major = 4,
        .context_version_minor = 3,
        .opengl_profile = .opengl_core_profile,
        .opengl_forward_compat = true,
    };
    var window = try glfw.Window.create(800, 600, "Hello", null, null, window_hints);
    defer window.destroy();
    try glfw.makeContextCurrent(window);

    // Initialize OpenGL
    try gl.load(@as(glfw.GLProc, undefined), glGetProcAddress);
    gl.viewport(0, 0, WIDTH, HEIGHT);
    gl.disable(gl.DEPTH_TEST);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    // Initialize vertex and fragment shaders
    const vs = gl.createShader(gl.VERTEX_SHADER);
    const fs = gl.createShader(gl.FRAGMENT_SHADER);
    gl.shaderSource(vs, 1, &[_][*c]const u8{vert_shader}, 0);
    gl.shaderSource(fs, 1, &[_][*c]const u8{frag_shader}, 0);
    gl.compileShader(vs);
    gl.compileShader(fs);

    program = gl.createProgram();
    gl.attachShader(program, vs);
    gl.attachShader(program, fs);
    gl.linkProgram(program);
    gl.useProgram(program);

    // Get shader uniforms
    gl.bindAttribLocation(program, 0, "pos");
    gl.uniform1i(gl.getUniformLocation(program, "tex"), 0);

    // Initialize VAO/VBO
    gl.genVertexArrays(1, &vao);
    gl.bindVertexArray(vao);
    gl.genBuffers(1, &vbo);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), null);

    // Load and create ASCII characters texture
    try loadCharacters();

    gl.clearColor(0, 0, 0, 1);
    while (!window.shouldClose()) {
        // Limit to 60fps
        std.time.sleep(16 * std.time.ns_per_ms);
        gl.clear(gl.COLOR_BUFFER_BIT);

        renderText("Hello Stephen!", -0.5, 0, 2.0 / @as(f32, WIDTH), .{ 1, 0.8, 0 });
        renderText("Hello Stephen!", -0.2, 0.2, 2.0 / @as(f32, HEIGHT), .{ 1, 0.8, 0 });

        try window.swapBuffers();
        try glfw.pollEvents();
    }
}

fn renderText(text: []const u8, x: f32, y: f32, scale: f32, color: [3]f32) void {
    var c_x = x;
    var c_y = y;
    for (text) |c| {
        const char = chars[c];

        const vx = c_x + @intToFloat(f32, char.left) * scale;
        const vy = c_y + @intToFloat(f32, char.top) * scale;
        const w = @intToFloat(f32, char.width) * scale;
        const h = @intToFloat(f32, char.rows) * scale;

        const data = [6][4]f32{
            .{ vx, vy, 0, 0 },
            .{ vx, vy - h, 0, 1 },
            .{ vx + w, vy, 1, 0 },
            .{ vx + w, vy, 1, 0 },
            .{ vx, vy - h, 0, 1 },
            .{ vx + w, vy - h, 1, 1 },
        };

        gl.uniform4f(gl.getUniformLocation(program, "color"), color[0], color[1], color[2], 1);
        gl.bindTexture(gl.TEXTURE_2D, char.id);
        gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(data)), &data, gl.DYNAMIC_DRAW);
        gl.drawArrays(gl.TRIANGLES, 0, 6);

        c_x += @intToFloat(f32, char.advance.x >> 6) * scale;
        c_y += @intToFloat(f32, char.advance.y >> 6) * scale;
    }
}

fn loadCharacters() !void {
    const ft_lib = try freetype.Library.init();
    defer ft_lib.deinit();
    const face = try ft_lib.createFaceMemory(firasans, 0);
    defer face.deinit();

    try face.setPixelSizes(0, 48);
    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);

    for (chars) |*c, i| {
        try face.loadChar(@intCast(u8, i), .{ .render = true });
        const glyph = face.glyph();

        var texture: u32 = 0;
        gl.genTextures(1, &texture);
        gl.bindTexture(gl.TEXTURE_2D, texture);
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.R8,
            @intCast(i32, glyph.bitmap().width()),
            @intCast(i32, glyph.bitmap().rows()),
            0,
            gl.RED,
            gl.UNSIGNED_BYTE,
            if (glyph.bitmap().buffer()) |b| b.ptr else null,
        );
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

        c.* = Character{
            .id = texture,
            .width = glyph.bitmap().width(),
            .rows = glyph.bitmap().rows(),
            .left = glyph.bitmapLeft(),
            .top = glyph.bitmapTop(),
            .advance = glyph.advance(),
        };
    }

    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 4);
}

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.FunctionPointer {
    _ = p;
    return glfw.getProcAddress(proc);
}
