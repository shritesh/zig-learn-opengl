const builtin = @import("builtin");
const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const math = @import("zmath");
const tau = std.math.tau;

const Camera = @import("./camera.zig").Camera;
const Model = @import("./model.zig").Model;
const Shader = @import("./shader.zig").Shader;

const wireframe_mode = false;

var camera = Camera.init(
    math.f32x4(0.0, 0.0, 3.0, 1.0),
    math.f32x4(0.0, 1.0, 0.0, 1.0),
);

var delta_time: f32 = 0;
var last_frame: f32 = 0;
var last_pos: ?struct { x: f32, y: f32 } = null;

pub fn main() !void {
    try glfw.init(.{});
    defer glfw.terminate();

    const window = try glfw.Window.create(800, 600, "Learn OpenGL", null, null, .{
        .context_version_major = 3,
        .context_version_minor = 3,
        .opengl_profile = .opengl_core_profile,
        .opengl_forward_compat = builtin.os.tag == .macos,
        .cocoa_retina_framebuffer = false,
    });
    defer window.destroy();

    try glfw.makeContextCurrent(window);
    try gl.load(glfw.getProcAddress);

    window.setFramebufferSizeCallback(framebufferSizeCallback);
    if (wireframe_mode) gl.polygonMode(.front_and_back, .line);

    try window.setInputModeCursor(.disabled);
    window.setCursorPosCallback(cursorPosCallback);
    window.setScrollCallback(scrollCallback);

    gl.enable(.depth_test);

    const shader = try Shader.init("shader.vert", "shader.frag", null);
    defer shader.deinit();

    const quad_vertices = [_]f32{
        -0.05, 0.05,  1.0, 0.0, 0.0,
        0.05,  -0.05, 0.0, 1.0, 0.0,
        -0.05, -0.05, 0.0, 0.0, 1.0,

        -0.05, 0.05,  1.0, 0.0, 0.0,
        0.05,  -0.05, 0.0, 1.0, 0.0,
        0.05,  0.05,  0.0, 1.0, 1.0,
    };

    var translations: [2 * 100]f32 = undefined;
    {
        var idx: usize = 0;
        var y: i16 = -10;
        while (y < 10) : (y += 2) {
            var x: i16 = -10;
            while (x < 10) : (x += 2) {
                translations[idx * 2] = @intToFloat(f32, x) / 10.0 + 0.1;
                translations[idx * 2 + 1] = @intToFloat(f32, y) / 10.0 + 0.1;

                idx += 1;
            }
        }
    }

    const vao = gl.genVertexArray();
    defer gl.deleteVertexArray(vao);
    gl.bindVertexArray(vao);

    const vbo = gl.genBuffer();
    defer gl.deleteBuffer(vbo);

    gl.bindBuffer(.array_buffer, vbo);
    gl.bufferData(.array_buffer, f32, &quad_vertices, .static_draw);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, .float, false, 5 * @sizeOf(f32), 0);

    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 3, .float, false, 5 * @sizeOf(f32), 2 * @sizeOf(f32));

    const ibo = gl.genBuffer();
    defer gl.deleteBuffer(ibo);

    gl.bindBuffer(.array_buffer, ibo);
    gl.bufferData(.array_buffer, f32, &translations, .static_draw);

    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 2, .float, false, 2 * @sizeOf(f32), 0);
    gl.vertexAttribDivisor(2, 1); // Each instance, not each vertex

    shader.use();

    while (!window.shouldClose()) {
        const current_frame = @floatCast(f32, glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;

        processInput(window);

        gl.clearColor(0.05, 0.05, 0.05, 1.0);
        gl.clear(.{ .color = true, .depth = true });

        shader.use();

        gl.drawArraysInstanced(.triangles, 0, 6, 100);

        try window.swapBuffers();
        try glfw.pollEvents();
    }
}

fn processInput(window: glfw.Window) void {
    if (window.getKey(.escape) == .press) {
        window.setShouldClose(true);
    }

    if (window.getKey(.w) == .press) {
        camera.processKeyboard(.forward, delta_time);
    }
    if (window.getKey(.s) == .press) {
        camera.processKeyboard(.backward, delta_time);
    }
    if (window.getKey(.a) == .press) {
        camera.processKeyboard(.left, delta_time);
    }
    if (window.getKey(.d) == .press) {
        camera.processKeyboard(.right, delta_time);
    }
}

fn framebufferSizeCallback(_: glfw.Window, width: u32, height: u32) void {
    gl.viewport(0, 0, width, height);
}

fn cursorPosCallback(_: glfw.Window, xpos: f64, ypos: f64) void {
    const x = @floatCast(f32, xpos);
    const y = @floatCast(f32, ypos);

    if (last_pos) |last| {
        var x_offset = x - last.x;
        var y_offset = last.y - y;
        camera.processMouseMovement(x_offset, y_offset, .{});
    }

    last_pos = .{ .x = x, .y = y };
}

fn scrollCallback(_: glfw.Window, _: f64, yoffset: f64) void {
    camera.processMouseScroll(@floatCast(f32, yoffset));
}
