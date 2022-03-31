const builtin = @import("builtin");
const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const math = @import("zmath");
const tau = std.math.tau;

const Camera = @import("./camera.zig").Camera;
const Image = @import("./image.zig").Image;
const Shader = @import("./shader.zig").Shader;

var blinn = false;

const allocator = std.heap.c_allocator;
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

    const floor_texture = try loadTexture("assets/wood.png");
    defer gl.deleteTexture(floor_texture);

    const plane_vertices = [_]f32{
        10.0,  -0.5, 10.0,  0.0, 1.0, 0.0, 10.0, 0.0,
        -10.0, -0.5, 10.0,  0.0, 1.0, 0.0, 0.0,  0.0,
        -10.0, -0.5, -10.0, 0.0, 1.0, 0.0, 0.0,  10.0,

        10.0,  -0.5, 10.0,  0.0, 1.0, 0.0, 10.0, 0.0,
        -10.0, -0.5, -10.0, 0.0, 1.0, 0.0, 0.0,  10.0,
        10.0,  -0.5, -10.0, 0.0, 1.0, 0.0, 10.0, 10.0,
    };

    const plane_vao = gl.genVertexArray();
    defer gl.deleteVertexArray(plane_vao);

    gl.bindVertexArray(plane_vao);

    const plane_vbo = gl.genBuffer();
    defer gl.deleteBuffer(plane_vbo);

    gl.bindBuffer(.array_buffer, plane_vbo);
    gl.bufferData(.array_buffer, f32, &plane_vertices, .static_draw);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, .float, false, 8 * @sizeOf(f32), 0);

    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, .float, false, 8 * @sizeOf(f32), 3 * @sizeOf(f32));

    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 2, .float, false, 8 * @sizeOf(f32), 6 * @sizeOf(f32));

    shader.use();
    shader.seti32("texture1", 0);
    gl.activeTexture(.texture0);

    while (!window.shouldClose()) {
        const current_frame = @floatCast(f32, glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;

        processInput(window);

        gl.clearColor(0.05, 0.05, 0.05, 1.0);
        gl.clear(.{ .color = true, .depth = true });

        const projection = math.perspectiveFovRh(camera.zoom * tau / 360.0, 800.0 / 600.0, 0.1, 100.0);
        const view = camera.viewMatrix();
        var model = math.translation(0.0, 0.0, 0.0);
        model = math.mul(math.scaling(1.0, 1.0, 1.0), model);

        shader.setVec3("viewPos", camera.position);
        shader.seti32("blinn", if (blinn) 1 else 0);

        shader.setMat("projection", projection);
        shader.setMat("view", view);
        shader.setMat("model", model);

        gl.bindVertexArray(plane_vao);
        gl.bindTexture(.@"2d", floor_texture);
        gl.drawArrays(.triangles, 0, 6);

        try window.swapBuffers();
        try glfw.pollEvents();
    }
}

fn processInput(window: glfw.Window) void {
    if (window.getKey(.escape) == .press) {
        window.setShouldClose(true);
    }

    if (window.getKey(.one) == .press) {
        blinn = false;
    }

    if (window.getKey(.two) == .press) {
        blinn = true;
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

fn loadTexture(file: [:0]const u8) !gl.Texture {
    const image = try Image.load(file, .{ .flip = true });
    defer image.unload();

    const format: gl.PixelFormat = switch (image.channels) {
        1 => .red,
        3 => .rgb,
        4 => .rgba,
        else => return error.ImageFormatError,
    };

    const texture = gl.genTexture();

    gl.bindTexture(.@"2d", texture);
    gl.texImage2D(.@"2d", 0, format, image.width, image.height, format, .unsigned_byte, image.data);
    gl.generateMipmap(.@"2d");

    gl.texParameter(.@"2d", .wrap_s, .repeat);
    gl.texParameter(.@"2d", .wrap_t, .repeat);
    gl.texParameter(.@"2d", .min_filter, .linear_mipmap_linear);
    gl.texParameter(.@"2d", .mag_filter, .linear);

    return texture;
}
