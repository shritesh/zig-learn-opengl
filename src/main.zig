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

    const shader = try Shader.init("shader.vert", "shader.frag");
    defer shader.deinit();

    const screen_shader = try Shader.init("framebuffer.vert", "framebuffer.frag");
    defer screen_shader.deinit();

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

    const quad_vertices = [_]f32{
        -0.3, 1.0, 0.0, 1.0,
        -0.3, 0.7, 0.0, 0.0,
        0.3,  0.7, 1.0, 0.0,

        -0.3, 1.0, 0.0, 1.0,
        0.3,  0.7, 1.0, 0.0,
        0.3,  1.0, 1.0, 1.0,
    };

    const cube_vao = gl.genVertexArray();
    defer gl.deleteVertexArray(cube_vao);
    gl.bindVertexArray(cube_vao);

    const cube_vbo = gl.genBuffer();
    defer gl.deleteBuffer(cube_vbo);

    gl.bindBuffer(.array_buffer, cube_vbo);
    gl.bufferData(.array_buffer, f32, &cube_vertices, .static_draw);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, .float, false, 5 * @sizeOf(f32), 0);

    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, .float, false, 5 * @sizeOf(f32), 3 * @sizeOf(f32));

    const plane_vao = gl.genVertexArray();
    defer gl.deleteVertexArray(plane_vao);
    gl.bindVertexArray(plane_vao);

    const plane_vbo = gl.genBuffer();
    defer gl.deleteBuffer(plane_vbo);

    gl.bindBuffer(.array_buffer, plane_vbo);
    gl.bufferData(.array_buffer, f32, &plane_vertices, .static_draw);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, .float, false, 5 * @sizeOf(f32), 0);

    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, .float, false, 5 * @sizeOf(f32), 3 * @sizeOf(f32));

    const quad_vao = gl.genVertexArray();
    defer gl.deleteVertexArray(quad_vao);
    gl.bindVertexArray(quad_vao);

    const quad_vbo = gl.genBuffer();
    defer gl.deleteBuffer(quad_vbo);

    gl.bindBuffer(.array_buffer, quad_vbo);
    gl.bufferData(.array_buffer, f32, &quad_vertices, .static_draw);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, .float, false, 4 * @sizeOf(f32), 0);

    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, .float, false, 4 * @sizeOf(f32), 2 * @sizeOf(f32));

    const cube_texture = try textureFromFile("assets/container.jpg");
    defer gl.deleteTexture(cube_texture);

    const floor_texture = try textureFromFile("assets/metal.png");
    defer gl.deleteTexture(floor_texture);

    shader.use();
    shader.seti32("texture1", 0);

    screen_shader.use();
    screen_shader.seti32("screenTexture", 0);

    const framebuffer = gl.genFramebuffer();
    defer gl.deleteFramebuffer(framebuffer);
    gl.bindFramebuffer(.framebuffer, framebuffer);

    const texture = gl.genTexture();
    gl.bindTexture(.@"2d", texture);
    gl.texImage2D(.@"2d", 0, .rgb, 800, 600, .rgb, .unsigned_byte, null);
    gl.texParameter(.@"2d", .wrap_s, .clamp_to_edge);
    gl.texParameter(.@"2d", .wrap_t, .clamp_to_edge);
    gl.texParameter(.@"2d", .min_filter, .linear);
    gl.texParameter(.@"2d", .mag_filter, .linear);
    gl.framebufferTexture2D(.framebuffer, .color0, .@"2d", texture, 0);

    const rbo = gl.genRenderbuffer();
    defer gl.deleteRenderbuffer(rbo);

    gl.bindRenderbuffer(.renderbuffer, rbo);
    gl.renderbufferStorage(.renderbuffer, .depth24_stencil8, 800, 600);
    gl.framebufferRenderbuffer(.framebuffer, .depth_stencil, .renderbuffer, rbo);

    if (gl.checkFramebufferStatus(.framebuffer) != .complete) return error.FramebufferInitError;
    gl.bindFramebuffer(.framebuffer, .none);

    while (!window.shouldClose()) {
        const current_frame = @floatCast(f32, glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;

        processInput(window);

        // Mirror pass
        gl.bindFramebuffer(.framebuffer, framebuffer);
        gl.enable(.depth_test);

        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(.{ .color = true, .depth = true });

        shader.use();

        const projection = math.perspectiveFovRh(camera.zoom * tau / 360.0, 800.0 / 600.0, 0.1, 100.0);

        // Flip camera
        camera.yaw += 180.0;
        var view = camera.viewMatrix();
        var model = math.identity();

        shader.setMat("projection", projection);
        shader.setMat("view", view);

        // Cubes
        gl.bindVertexArray(cube_vao);
        gl.activeTexture(.texture0);
        gl.bindTexture(.@"2d", cube_texture);

        model = math.translation(-1.0, 0.0, -1.0);
        shader.setMat("model", model);
        gl.drawArrays(.triangles, 0, 36);

        model = math.translation(2.0, 0.0, 0.0);
        shader.setMat("model", model);
        gl.drawArrays(.triangles, 0, 36);

        // Floor
        gl.bindVertexArray(plane_vao);
        gl.bindTexture(.@"2d", floor_texture);
        model = math.identity();
        shader.setMat("model", model);
        gl.drawArrays(.triangles, 0, 6);

        gl.bindVertexArray(.none);

        // Reset camera
        camera.yaw -= 180.0;
        view = camera.viewMatrix();
        shader.setMat("view", view);

        // Draw in screen
        gl.bindFramebuffer(.framebuffer, .none);

        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(.{ .color = true, .depth = true });

        shader.setMat("projection", projection);
        shader.setMat("view", view);

        // Cubes
        gl.bindVertexArray(cube_vao);
        gl.activeTexture(.texture0);
        gl.bindTexture(.@"2d", cube_texture);

        model = math.translation(-1.0, 0.0, -1.0);
        shader.setMat("model", model);
        gl.drawArrays(.triangles, 0, 36);

        model = math.translation(2.0, 0.0, 0.0);
        shader.setMat("model", model);
        gl.drawArrays(.triangles, 0, 36);

        // Floor
        gl.bindVertexArray(plane_vao);
        gl.bindTexture(.@"2d", floor_texture);
        model = math.identity();
        shader.setMat("model", model);
        gl.drawArrays(.triangles, 0, 6);

        // Draw texture
        gl.disable(.depth_test);

        screen_shader.use();
        gl.bindVertexArray(quad_vao);
        gl.bindTexture(.@"2d", texture);
        gl.drawArrays(.triangles, 0, 6);

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

    gl.bindTexture(.@"2d", texture);
    gl.texImage2D(.@"2d", 0, format, image.width, image.height, format, .unsigned_byte, image.data);
    gl.generateMipmap(.@"2d");

    gl.texParameter(.@"2d", .wrap_s, .repeat);
    gl.texParameter(.@"2d", .wrap_t, .repeat);
    gl.texParameter(.@"2d", .min_filter, .linear_mipmap_linear);
    gl.texParameter(.@"2d", .mag_filter, .linear);

    return texture;
}
