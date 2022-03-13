const builtin = @import("builtin");
const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const math = @import("zmath");

const tau = std.math.tau;

const Image = @import("./image.zig").Image;
const Shader = @import("./shader.zig").Shader;

const wireframe_mode = false;

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
    gl.enable(.depth_test);

    const container_image = try Image.load(@embedFile("../assets/container.jpg"), .{});
    defer container_image.unload();

    const face_image = try Image.load(@embedFile("../assets/awesomeface.png"), .{ .flip = true });
    defer face_image.unload();

    const shader = try Shader.init(@embedFile("triangle.vert"), @embedFile("triangle.frag"));
    defer shader.deinit();

    const vertices = [_]f32{
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

    const cube_positions = [_]math.Vec{
        .{ 0.0, 0.0, 0.0 },
        .{ 2.0, 5.0, -15.0 },
        .{ -1.5, -2.2, -2.5 },
        .{ -3.8, -2.0, -12.3 },
        .{ 2.4, -0.4, -3.5 },
        .{ -1.7, 3.0, -7.5 },
        .{ 1.3, -2.0, -2.5 },
        .{ 1.5, 2.0, -2.5 },
        .{ 1.5, 0.2, -1.5 },
        .{ -1.3, 1.0, -1.5 },
    };

    const vao = gl.genVertexArray();
    defer vao.delete();

    const vbo = gl.genBuffer();
    defer vbo.delete();

    vao.bind();

    vbo.bind(.array_buffer);
    gl.bufferData(.array_buffer, f32, &vertices, .static_draw);

    gl.vertexAttribPointer(0, 3, .float, false, 5 * @sizeOf(f32), 0);
    gl.enableVertexAttribArray(0);

    gl.vertexAttribPointer(1, 2, .float, false, 5 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.enableVertexAttribArray(1);

    const texture0 = gl.genTexture();
    defer texture0.delete();

    gl.activeTexture(.texture_0);
    texture0.bind(.@"2d");
    gl.texParameter(.@"2d", .wrap_s, .repeat);
    gl.texParameter(.@"2d", .wrap_t, .repeat);
    gl.texParameter(.@"2d", .min_filter, .linear);
    gl.texParameter(.@"2d", .mag_filter, .linear);
    gl.textureImage2D(.@"2d", 0, .rgb, container_image.width, container_image.height, .rgb, .unsigned_byte, container_image.data);
    gl.generateMipmap(.@"2d");

    const texture1 = gl.genTexture();
    defer texture1.delete();

    gl.activeTexture(.texture_1);
    texture1.bind(.@"2d");
    gl.texParameter(.@"2d", .wrap_s, .repeat);
    gl.texParameter(.@"2d", .wrap_t, .repeat);
    gl.texParameter(.@"2d", .min_filter, .linear);
    gl.texParameter(.@"2d", .mag_filter, .linear);
    gl.textureImage2D(.@"2d", 0, .rgb, face_image.width, face_image.height, .rgba, .unsigned_byte, face_image.data);
    gl.generateMipmap(.@"2d");

    shader.use();
    shader.set("texture0", i32, 0);
    shader.set("texture1", i32, 1);

    const view = math.translation(0.0, 0.0, -3.0);
    const projection = math.perspectiveFovRh(tau / 8.0, 800.0 / 600.0, 0.1, 100.0);
    shader.set("view", math.Mat, view);
    shader.set("projection", math.Mat, projection);

    while (!window.shouldClose()) {
        processInput(window);

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(.{ .color = true, .depth = true });

        for (cube_positions) |position, i| {
            const angle = 20.0 * @intToFloat(f32, i);

            var model = math.translationV(position);
            model = math.mul(math.matFromAxisAngle(.{ 1.0, 0.3, 0.5 }, angle), model);
            shader.set("model", math.Mat, model);
            gl.drawArrays(.triangles, 0, 36);
        }

        try window.swapBuffers();
        try glfw.pollEvents();
    }
}

fn processInput(window: glfw.Window) void {
    if (window.getKey(.q) == .press) {
        window.setShouldClose(true);
    }
}

fn framebufferSizeCallback(_: glfw.Window, width: u32, height: u32) void {
    gl.viewport(0, 0, width, height);
}
