const builtin = @import("builtin");
const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const math = @import("zmath");
const tau = std.math.tau;

const Camera = @import("./camera.zig").Camera;
const Shader = @import("./shader.zig").Shader;

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

    const screen_shader = try Shader.init("screen.vert", "screen.frag", null);
    defer screen_shader.deinit();

    const cube_vertices = [_]f32{
        -0.5, -0.5, -0.5,
        0.5,  -0.5, -0.5,
        0.5,  0.5,  -0.5,
        0.5,  0.5,  -0.5,
        -0.5, 0.5,  -0.5,
        -0.5, -0.5, -0.5,

        -0.5, -0.5, 0.5,
        0.5,  -0.5, 0.5,
        0.5,  0.5,  0.5,
        0.5,  0.5,  0.5,
        -0.5, 0.5,  0.5,
        -0.5, -0.5, 0.5,

        -0.5, 0.5,  0.5,
        -0.5, 0.5,  -0.5,
        -0.5, -0.5, -0.5,
        -0.5, -0.5, -0.5,
        -0.5, -0.5, 0.5,
        -0.5, 0.5,  0.5,

        0.5,  0.5,  0.5,
        0.5,  0.5,  -0.5,
        0.5,  -0.5, -0.5,
        0.5,  -0.5, -0.5,
        0.5,  -0.5, 0.5,
        0.5,  0.5,  0.5,

        -0.5, -0.5, -0.5,
        0.5,  -0.5, -0.5,
        0.5,  -0.5, 0.5,
        0.5,  -0.5, 0.5,
        -0.5, -0.5, 0.5,
        -0.5, -0.5, -0.5,

        -0.5, 0.5,  -0.5,
        0.5,  0.5,  -0.5,
        0.5,  0.5,  0.5,
        0.5,  0.5,  0.5,
        -0.5, 0.5,  0.5,
        -0.5, 0.5,  -0.5,
    };

    const quad_vertices = [_]f32{
        -1.0, 1.0,  0.0, 1.0,
        -1.0, -1.0, 0.0, 0.0,
        1.0,  -1.0, 1.0, 0.0,

        -1.0, 1.0,  0.0, 1.0,
        1.0,  -1.0, 1.0, 0.0,
        1.0,  1.0,  1.0, 1.0,
    };

    const cube_vao = gl.genVertexArray();
    defer gl.deleteVertexArray(cube_vao);
    gl.bindVertexArray(cube_vao);

    const cube_vbo = gl.genBuffer();
    defer gl.deleteBuffer(cube_vbo);

    gl.bindBuffer(.array_buffer, cube_vbo);
    gl.bufferData(.array_buffer, f32, &cube_vertices, .static_draw);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, .float, false, 3 * @sizeOf(f32), 0);

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

    // MSAA Framebuffer
    const fbo = gl.genFramebuffer();
    defer gl.deleteFramebuffer(fbo);

    gl.bindFramebuffer(.framebuffer, fbo);

    const texture = gl.genTexture();
    defer gl.deleteTexture(texture);

    gl.bindTexture(.@"2d_multisample", texture);
    gl.texImage2DMultisample(.@"2d_multisample", 4, .rgb, 800, 600, true);
    gl.bindTexture(.@"2d_multisample", .none);

    gl.framebufferTexture2D(.framebuffer, .color0, .@"2d_multisample", texture, 0);

    const rbo = gl.genRenderbuffer();
    defer gl.deleteRenderbuffer(rbo);

    gl.bindRenderbuffer(.renderbuffer, rbo);
    gl.renderbufferStorageMultisample(.renderbuffer, 4, .depth24_stencil8, 800, 600);
    gl.bindRenderbuffer(.renderbuffer, .none);

    gl.framebufferRenderbuffer(.framebuffer, .depth_stencil, .renderbuffer, rbo);

    if (gl.checkFramebufferStatus(.framebuffer) != .complete) return error.FramebufferIncompleteError;

    const i_fbo = gl.genFramebuffer();
    defer gl.deleteFramebuffer(i_fbo);

    gl.bindFramebuffer(.framebuffer, i_fbo);

    const screen_texture = gl.genTexture();
    defer gl.deleteTexture(screen_texture);

    gl.bindTexture(.@"2d", screen_texture);
    gl.texImage2D(.@"2d", 0, .rgb, 800, 600, .rgb, .unsigned_byte, null);
    gl.texParameter(.@"2d", .min_filter, .linear);
    gl.texParameter(.@"2d", .mag_filter, .linear);
    gl.framebufferTexture2D(.framebuffer, .color0, .@"2d", screen_texture, 0);

    if (gl.checkFramebufferStatus(.framebuffer) != .complete) return error.FramebufferIncompleteError;

    while (!window.shouldClose()) {
        const current_frame = @floatCast(f32, glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;

        processInput(window);

        // Draw scene
        gl.bindFramebuffer(.framebuffer, fbo);
        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(.{ .color = true, .depth = true });
        gl.enable(.depth_test);

        const projection = math.perspectiveFovRh(camera.zoom * tau / 360.0, 800.0 / 600.0, 0.1, 1000.0);
        const view = camera.viewMatrix();
        const model = math.identity();

        shader.use();
        shader.setMat("projection", projection);
        shader.setMat("view", view);
        shader.setMat("model", model);
        gl.bindVertexArray(cube_vao);
        gl.drawArrays(.triangles, 0, 36);

        // Blit to i_fbo
        gl.bindFramebuffer(.read_framebuffer, fbo);
        gl.bindFramebuffer(.draw_fraembuffer, i_fbo);
        gl.blitFramebuffer(0, 0, 800, 600, 0, 0, 800, 600, .{ .color = true }, .nearest);

        // Render quad
        gl.bindFramebuffer(.framebuffer, .none);
        gl.clearColor(1.0, 1.0, 1.0, 1.0);
        gl.clear(.{ .color = true });
        gl.disable(.depth_test);

        screen_shader.use();
        gl.bindVertexArray(quad_vao);
        gl.activeTexture(.texture0);
        gl.bindTexture(.@"2d", screen_texture);
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
