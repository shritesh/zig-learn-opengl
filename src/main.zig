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

    const shader = try Shader.init("shader.vert", "shader.frag");
    defer shader.deinit();

    const skybox_shader = try Shader.init("skybox.vert", "skybox.frag");
    defer skybox_shader.deinit();

    const skybox_texture = try loadCubemap(.{
        "assets/skybox/right.jpg",
        "assets/skybox/left.jpg",
        "assets/skybox/top.jpg",
        "assets/skybox/bottom.jpg",
        "assets/skybox/front.jpg",
        "assets/skybox/back.jpg",
    });
    defer gl.deleteTexture(skybox_texture);

    const cube_vertices = [_]f32{
        -0.5, -0.5, -0.5, 0.0,  0.0,  -1.0,
        0.5,  -0.5, -0.5, 0.0,  0.0,  -1.0,
        0.5,  0.5,  -0.5, 0.0,  0.0,  -1.0,
        0.5,  0.5,  -0.5, 0.0,  0.0,  -1.0,
        -0.5, 0.5,  -0.5, 0.0,  0.0,  -1.0,
        -0.5, -0.5, -0.5, 0.0,  0.0,  -1.0,

        -0.5, -0.5, 0.5,  0.0,  0.0,  1.0,
        0.5,  -0.5, 0.5,  0.0,  0.0,  1.0,
        0.5,  0.5,  0.5,  0.0,  0.0,  1.0,
        0.5,  0.5,  0.5,  0.0,  0.0,  1.0,
        -0.5, 0.5,  0.5,  0.0,  0.0,  1.0,
        -0.5, -0.5, 0.5,  0.0,  0.0,  1.0,

        -0.5, 0.5,  0.5,  -1.0, 0.0,  0.0,
        -0.5, 0.5,  -0.5, -1.0, 0.0,  0.0,
        -0.5, -0.5, -0.5, -1.0, 0.0,  0.0,
        -0.5, -0.5, -0.5, -1.0, 0.0,  0.0,
        -0.5, -0.5, 0.5,  -1.0, 0.0,  0.0,
        -0.5, 0.5,  0.5,  -1.0, 0.0,  0.0,

        0.5,  0.5,  0.5,  1.0,  0.0,  0.0,
        0.5,  0.5,  -0.5, 1.0,  0.0,  0.0,
        0.5,  -0.5, -0.5, 1.0,  0.0,  0.0,
        0.5,  -0.5, -0.5, 1.0,  0.0,  0.0,
        0.5,  -0.5, 0.5,  1.0,  0.0,  0.0,
        0.5,  0.5,  0.5,  1.0,  0.0,  0.0,

        -0.5, -0.5, -0.5, 0.0,  -1.0, 0.0,
        0.5,  -0.5, -0.5, 0.0,  -1.0, 0.0,
        0.5,  -0.5, 0.5,  0.0,  -1.0, 0.0,
        0.5,  -0.5, 0.5,  0.0,  -1.0, 0.0,
        -0.5, -0.5, 0.5,  0.0,  -1.0, 0.0,
        -0.5, -0.5, -0.5, 0.0,  -1.0, 0.0,

        -0.5, 0.5,  -0.5, 0.0,  1.0,  0.0,
        0.5,  0.5,  -0.5, 0.0,  1.0,  0.0,
        0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
        0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
        -0.5, 0.5,  0.5,  0.0,  1.0,  0.0,
        -0.5, 0.5,  -0.5, 0.0,  1.0,  0.0,
    };

    const skybox_vertices = [_]f32{
        -1.0, 1.0,  -1.0,
        -1.0, -1.0, -1.0,
        1.0,  -1.0, -1.0,
        1.0,  -1.0, -1.0,
        1.0,  1.0,  -1.0,
        -1.0, 1.0,  -1.0,

        -1.0, -1.0, 1.0,
        -1.0, -1.0, -1.0,
        -1.0, 1.0,  -1.0,
        -1.0, 1.0,  -1.0,
        -1.0, 1.0,  1.0,
        -1.0, -1.0, 1.0,

        1.0,  -1.0, -1.0,
        1.0,  -1.0, 1.0,
        1.0,  1.0,  1.0,
        1.0,  1.0,  1.0,
        1.0,  1.0,  -1.0,
        1.0,  -1.0, -1.0,

        -1.0, -1.0, 1.0,
        -1.0, 1.0,  1.0,
        1.0,  1.0,  1.0,
        1.0,  1.0,  1.0,
        1.0,  -1.0, 1.0,
        -1.0, -1.0, 1.0,

        -1.0, 1.0,  -1.0,
        1.0,  1.0,  -1.0,
        1.0,  1.0,  1.0,
        1.0,  1.0,  1.0,
        -1.0, 1.0,  1.0,
        -1.0, 1.0,  -1.0,

        -1.0, -1.0, -1.0,
        -1.0, -1.0, 1.0,
        1.0,  -1.0, -1.0,
        1.0,  -1.0, -1.0,
        -1.0, -1.0, 1.0,
        1.0,  -1.0, 1.0,
    };

    const cube_vao = gl.genVertexArray();
    defer gl.deleteVertexArray(cube_vao);
    gl.bindVertexArray(cube_vao);

    const cube_vbo = gl.genBuffer();
    defer gl.deleteBuffer(cube_vbo);

    gl.bindBuffer(.array_buffer, cube_vbo);
    gl.bufferData(.array_buffer, f32, &cube_vertices, .static_draw);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, .float, false, 6 * @sizeOf(f32), 0);

    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 3, .float, false, 6 * @sizeOf(f32), 3 * @sizeOf(f32));

    const skybox_vao = gl.genVertexArray();
    defer gl.deleteVertexArray(skybox_vao);
    gl.bindVertexArray(skybox_vao);

    const skybox_vbo = gl.genBuffer();
    defer gl.deleteBuffer(skybox_vbo);

    gl.bindBuffer(.array_buffer, skybox_vbo);
    gl.bufferData(.array_buffer, f32, &skybox_vertices, .static_draw);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, .float, false, 3 * @sizeOf(f32), 0);

    shader.use();
    shader.seti32("skybox", 0);

    skybox_shader.use();
    skybox_shader.seti32("skybox", 0);

    gl.activeTexture(.texture0);

    while (!window.shouldClose()) {
        const current_frame = @floatCast(f32, glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;

        processInput(window);

        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(.{ .color = true, .depth = true });

        const projection = math.perspectiveFovRh(camera.zoom * tau / 360.0, 800.0 / 600.0, 0.1, 100.0);
        const model = math.identity();
        var view = camera.viewMatrix();

        // Draw cube
        shader.use();
        shader.setMat("projection", projection);
        shader.setMat("view", view);
        shader.setMat("model", model);
        shader.setVec3("cameraPos", camera.position);

        gl.bindVertexArray(cube_vao);
        gl.bindTexture(.cube_map, skybox_texture);
        gl.drawArrays(.triangles, 0, 36);

        // Draw skybox
        gl.depthFunc(.less_or_equal);
        skybox_shader.use();

        // FIXME: view = mat4(mat3(view));
        view[0][3] = 0.0;
        view[1][3] = 0.0;
        view[2][3] = 0.0;
        view[3][0] = 0.0;
        view[3][1] = 0.0;
        view[3][2] = 0.0;
        view[3][3] = 1.0;

        skybox_shader.setMat("projection", projection);
        skybox_shader.setMat("view", view);

        gl.bindVertexArray(skybox_vao);
        gl.bindTexture(.cube_map, skybox_texture);
        gl.drawArrays(.triangles, 0, 36);
        gl.depthFunc(.less);

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

fn loadCubemap(faces: [6][:0]const u8) !gl.Texture {
    const texture = gl.genTexture();
    errdefer gl.deleteTexture(texture);

    gl.bindTexture(.cube_map, texture);

    for (faces) |face, i| {
        const image = try Image.load(face, .{});
        defer image.unload();

        gl.texImage2D(@intToEnum(gl.TextureTarget, @enumToInt(gl.TextureTarget.cube_map_positive_x) + i), 0, .rgb, image.width, image.height, .rgb, .unsigned_byte, image.data);
    }

    gl.texParameter(.cube_map, .min_filter, .linear);
    gl.texParameter(.cube_map, .mag_filter, .linear);
    gl.texParameter(.cube_map, .wrap_s, .clamp_to_edge);
    gl.texParameter(.cube_map, .wrap_t, .clamp_to_edge);
    gl.texParameter(.cube_map, .wrap_r, .clamp_to_edge);

    return texture;
}
