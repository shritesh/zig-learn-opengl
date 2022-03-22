const builtin = @import("builtin");
const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const math = @import("zmath");

const tau = std.math.tau;

const Camera = @import("./camera.zig").Camera;
const Image = @import("./image.zig").Image;
const Shader = @import("./shader.zig").Shader;

const wireframe_mode = false;

var camera = Camera.init(
    math.f32x4(0.0, 0.0, 3.0, 1.0),
    math.f32x4(0.0, 1.0, 0.0, 1.0),
);

var delta_time: f32 = 0;
var last_frame: f32 = 0;
var first_mouse = true;
var last_x: f32 = 400.0;
var last_y: f32 = 300.0;

pub fn main() !void {
    try glfw.init(.{});
    defer glfw.terminate();

    const window = try glfw.Window.create(800, 600, "Learn OpenGL", null, null, .{
        .context_version_major = 3,
        .context_version_minor = 3,
        .opengl_profile = .opengl_core_profile,
        .opengl_forward_compat = builtin.os.tag == .macos,
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
    gl.depthFunc(.less);
    gl.enable(.stencil_test);
    gl.stencilFunc(.not_equal, 1, 0xff);
    gl.stencilOp(.keep, .keep, .replace);

    const shader = try Shader.init("shader.vert", "shader.frag");
    defer shader.deinit();

    const shader_single_color = try Shader.init("shader.vert", "single_color.frag");
    defer shader_single_color.deinit();

    const cube_vertices = [_]f32{
        -0.5, -0.5, -0.5, 0.0, 0.0,
        0.5,  -0.5, -0.5, 1.0, 0.0,
        0.5,  0.5,  -0.5, 1.0, 1.0,
        0.5,  0.5,  -0.5, 1.0, 1.0,
        -0.5, 0.5,  -0.5, 0.0, 1.0,
        -0.5, -0.5, -0.5, 0.0, 0.0,

        -0.5, -0.5, 0.5,  0.0, 0.0,
        0.5,  -0.5, 0.5,  1.0, 0.0,
        0.5,  0.5,  0.5,  1.0, 1.0,
        0.5,  0.5,  0.5,  1.0, 1.0,
        -0.5, 0.5,  0.5,  0.0, 1.0,
        -0.5, -0.5, 0.5,  0.0, 0.0,

        -0.5, 0.5,  0.5,  1.0, 0.0,
        -0.5, 0.5,  -0.5, 1.0, 1.0,
        -0.5, -0.5, -0.5, 0.0, 1.0,
        -0.5, -0.5, -0.5, 0.0, 1.0,
        -0.5, -0.5, 0.5,  0.0, 0.0,
        -0.5, 0.5,  0.5,  1.0, 0.0,

        0.5,  0.5,  0.5,  1.0, 0.0,
        0.5,  0.5,  -0.5, 1.0, 1.0,
        0.5,  -0.5, -0.5, 0.0, 1.0,
        0.5,  -0.5, -0.5, 0.0, 1.0,
        0.5,  -0.5, 0.5,  0.0, 0.0,
        0.5,  0.5,  0.5,  1.0, 0.0,

        -0.5, -0.5, -0.5, 0.0, 1.0,
        0.5,  -0.5, -0.5, 1.0, 1.0,
        0.5,  -0.5, 0.5,  1.0, 0.0,
        0.5,  -0.5, 0.5,  1.0, 0.0,
        -0.5, -0.5, 0.5,  0.0, 0.0,
        -0.5, -0.5, -0.5, 0.0, 1.0,

        -0.5, 0.5,  -0.5, 0.0, 1.0,
        0.5,  0.5,  -0.5, 1.0, 1.0,
        0.5,  0.5,  0.5,  1.0, 0.0,
        0.5,  0.5,  0.5,  1.0, 0.0,
        -0.5, 0.5,  0.5,  0.0, 0.0,
        -0.5, 0.5,  -0.5, 0.0, 1.0,
    };

    const plane_vertices = [_]f32{
        5.0,  -0.5, 5.0,  2.0, 0.0,
        -5.0, -0.5, 5.0,  0.0, 0.0,
        -5.0, -0.5, -5.0, 0.0, 2.0,

        5.0,  -0.5, 5.0,  2.0, 0.0,
        -5.0, -0.5, -5.0, 0.0, 2.0,
        5.0,  -0.5, -5.0, 2.0, 2.0,
    };

    const cube_vao = gl.genVertexArray();
    defer cube_vao.delete();
    cube_vao.bind();

    const cube_vbo = gl.genBuffer();
    defer cube_vbo.delete();

    cube_vbo.bind(.array_buffer);
    gl.bufferData(.array_buffer, f32, &cube_vertices, .static_draw);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, .float, false, 5 * @sizeOf(f32), 0);

    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, .float, false, 5 * @sizeOf(f32), 3 * @sizeOf(f32));

    const plane_vao = gl.genVertexArray();
    defer plane_vao.delete();
    plane_vao.bind();

    const plane_vbo = gl.genBuffer();
    defer plane_vbo.delete();

    plane_vbo.bind(.array_buffer);
    gl.bufferData(.array_buffer, f32, &plane_vertices, .static_draw);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, .float, false, 5 * @sizeOf(f32), 0);

    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, .float, false, 5 * @sizeOf(f32), 3 * @sizeOf(f32));

    const cube_texture = try textureFromFile("assets/marble.jpg");
    defer cube_texture.delete();

    const floor_texture = try textureFromFile("assets/metal.png");
    defer floor_texture.delete();

    shader.use();
    shader.seti32("texture1", 0);

    while (!window.shouldClose()) {
        const current_frame = @floatCast(f32, glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;

        processInput(window);

        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(.{ .color = true, .depth = true, .stencil = true });

        const projection = math.perspectiveFovRh(camera.zoom * tau / 360.0, 800.0 / 600.0, 0.1, 100.0);
        const view = camera.viewMatrix();
        var model = math.identity();

        shader_single_color.use();
        shader_single_color.setMat("projection", projection);
        shader_single_color.setMat("view", view);

        shader.use();
        shader.setMat("projection", projection);
        shader.setMat("view", view);

        // Floor
        // Don't write stencil mask
        gl.stencilMask(0x00);

        plane_vao.bind();
        floor_texture.bind(.@"2d");
        model = math.identity();
        gl.drawArrays(.triangles, 0, 6);

        // First Render pass. Write to stencil buffer
        gl.stencilFunc(.always, 1, 0xff);
        gl.stencilMask(0xff);

        // Cubes
        cube_vao.bind();
        gl.activeTexture(.texture_0);
        cube_texture.bind(.@"2d");

        model = math.translation(-1.0, 0.0, -1.0);
        shader.setMat("model", model);
        gl.drawArrays(.triangles, 0, 36);

        model = math.translation(2.0, 0.0, 0.0);
        shader.setMat("model", model);
        gl.drawArrays(.triangles, 0, 36);

        // Second render pass. Disable stencil writing.
        // Slightly larger objects
        const scaling = math.f32x4(1.1, 1.1, 1.1, 1.0);
        gl.stencilFunc(.not_equal, 1, 0xff);
        gl.stencilMask(0x00);
        gl.disable(.depth_test);
        shader_single_color.use();

        // Cubes
        cube_vao.bind();
        gl.activeTexture(.texture_0);
        cube_texture.bind(.@"2d");

        model = math.translation(-1.0, 0.0, -1.0);
        model = math.mul(math.scalingV(scaling), model);
        shader.setMat("model", model);
        gl.drawArrays(.triangles, 0, 36);

        model = math.translation(2.0, 0.0, 0.0);
        model = math.mul(math.scalingV(scaling), model);
        shader.setMat("model", model);
        gl.drawArrays(.triangles, 0, 36);

        gl.stencilMask(0xff);
        gl.stencilFunc(.always, 0, 0xff);
        gl.enable(.depth_test);

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

    if (first_mouse) {
        last_x = x;
        last_y = y;
        first_mouse = false;
    }

    var x_offset = x - last_x;
    var y_offset = last_y - y;

    last_x = x;
    last_y = y;

    camera.processMouseMovement(x_offset, y_offset, .{});
}

fn scrollCallback(_: glfw.Window, _: f64, yoffset: f64) void {
    camera.processMouseScroll(@floatCast(f32, yoffset));
}

fn textureFromFile(file: [:0]const u8) !gl.Texture {
    const image = try Image.load(file, .{ .flip = true });
    defer image.unload();

    const format: gl.PixelFormat = switch (image.channels) {
        1 => .red,
        3 => .rgb,
        4 => .rgba,
        else => return error.ImageFormatError,
    };

    const texture = gl.genTexture();

    texture.bind(.@"2d");
    gl.textureImage2D(.@"2d", 0, format, image.width, image.height, format, .unsigned_byte, image.data);
    gl.generateMipmap(.@"2d");

    gl.texParameter(.@"2d", .wrap_s, .repeat);
    gl.texParameter(.@"2d", .wrap_t, .repeat);
    gl.texParameter(.@"2d", .min_filter, .linear_mipmap_linear);
    gl.texParameter(.@"2d", .mag_filter, .linear);

    return texture;
}
