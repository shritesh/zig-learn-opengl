const builtin = @import("builtin");
const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const math = @import("zmath");
const assimp = @cImport({
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});

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

    const diffuse_image = try Image.load(@embedFile("../assets/container2.png"), .{});
    defer diffuse_image.unload();

    const specular_image = try Image.load(@embedFile("../assets/container2_specular.png"), .{});
    defer specular_image.unload();

    const lighting_shader = try Shader.init("lighting.vert", "lighting.frag");
    defer lighting_shader.deinit();

    const light_cube_shader = try Shader.init("light_cube.vert", "light_cube.frag");
    defer light_cube_shader.deinit();

    const vertices = [_]f32{
        -0.5, -0.5, -0.5, 0.0,  0.0,  -1.0, 0.0, 0.0,
        0.5,  -0.5, -0.5, 0.0,  0.0,  -1.0, 1.0, 0.0,
        0.5,  0.5,  -0.5, 0.0,  0.0,  -1.0, 1.0, 1.0,
        0.5,  0.5,  -0.5, 0.0,  0.0,  -1.0, 1.0, 1.0,
        -0.5, 0.5,  -0.5, 0.0,  0.0,  -1.0, 0.0, 1.0,
        -0.5, -0.5, -0.5, 0.0,  0.0,  -1.0, 0.0, 0.0,

        -0.5, -0.5, 0.5,  0.0,  0.0,  1.0,  0.0, 0.0,
        0.5,  -0.5, 0.5,  0.0,  0.0,  1.0,  1.0, 0.0,
        0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 1.0,
        0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 1.0,
        -0.5, 0.5,  0.5,  0.0,  0.0,  1.0,  0.0, 1.0,
        -0.5, -0.5, 0.5,  0.0,  0.0,  1.0,  0.0, 0.0,

        -0.5, 0.5,  0.5,  -1.0, 0.0,  0.0,  1.0, 0.0,
        -0.5, 0.5,  -0.5, -1.0, 0.0,  0.0,  1.0, 1.0,
        -0.5, -0.5, -0.5, -1.0, 0.0,  0.0,  0.0, 1.0,
        -0.5, -0.5, -0.5, -1.0, 0.0,  0.0,  0.0, 1.0,
        -0.5, -0.5, 0.5,  -1.0, 0.0,  0.0,  0.0, 0.0,
        -0.5, 0.5,  0.5,  -1.0, 0.0,  0.0,  1.0, 0.0,

        0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,
        0.5,  0.5,  -0.5, 1.0,  0.0,  0.0,  1.0, 1.0,
        0.5,  -0.5, -0.5, 1.0,  0.0,  0.0,  0.0, 1.0,
        0.5,  -0.5, -0.5, 1.0,  0.0,  0.0,  0.0, 1.0,
        0.5,  -0.5, 0.5,  1.0,  0.0,  0.0,  0.0, 0.0,
        0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,

        -0.5, -0.5, -0.5, 0.0,  -1.0, 0.0,  0.0, 1.0,
        0.5,  -0.5, -0.5, 0.0,  -1.0, 0.0,  1.0, 1.0,
        0.5,  -0.5, 0.5,  0.0,  -1.0, 0.0,  1.0, 0.0,
        0.5,  -0.5, 0.5,  0.0,  -1.0, 0.0,  1.0, 0.0,
        -0.5, -0.5, 0.5,  0.0,  -1.0, 0.0,  0.0, 0.0,
        -0.5, -0.5, -0.5, 0.0,  -1.0, 0.0,  0.0, 1.0,

        -0.5, 0.5,  -0.5, 0.0,  1.0,  0.0,  0.0, 1.0,
        0.5,  0.5,  -0.5, 0.0,  1.0,  0.0,  1.0, 1.0,
        0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
        0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
        -0.5, 0.5,  0.5,  0.0,  1.0,  0.0,  0.0, 0.0,
        -0.5, 0.5,  -0.5, 0.0,  1.0,  0.0,  0.0, 1.0,
    };

    const cube_positions = [_]math.F32x4{
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

    const point_light_positions = [_]math.F32x4{
        .{ 0.7, 0.2, 2.0 },
        .{ 2.3, -3.3, -4.0 },
        .{ -4.0, 2.0, -12.0 },
        .{ 0.0, 0.0, -3.0 },
    };

    const cube_vao = gl.genVertexArray();
    defer cube_vao.delete();

    cube_vao.bind();

    const vbo = gl.genBuffer();
    defer vbo.delete();

    vbo.bind(.array_buffer);
    gl.bufferData(.array_buffer, f32, &vertices, .static_draw);

    gl.vertexAttribPointer(0, 3, .float, false, 8 * @sizeOf(f32), 0);
    gl.enableVertexAttribArray(0);

    gl.vertexAttribPointer(1, 3, .float, false, 8 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.enableVertexAttribArray(1);

    gl.vertexAttribPointer(2, 2, .float, false, 8 * @sizeOf(f32), 6 * @sizeOf(f32));
    gl.enableVertexAttribArray(2);

    const diffuse_texture = try textureFromImage(diffuse_image, .texture_0);
    defer diffuse_texture.delete();

    const specular_texture = try textureFromImage(specular_image, .texture_1);
    defer specular_texture.delete();

    const light_cube_vao = gl.genVertexArray();
    defer light_cube_vao.delete();

    light_cube_vao.bind();

    vbo.bind(.array_buffer);

    gl.vertexAttribPointer(0, 3, .float, false, 8 * @sizeOf(f32), 0);
    gl.enableVertexAttribArray(0);

    while (!window.shouldClose()) {
        const current_frame = @floatCast(f32, glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;

        processInput(window);

        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(.{ .color = true, .depth = true });

        const projection = math.perspectiveFovRh(camera.zoom * tau / 360.0, 800.0 / 600.0, 0.1, 100.0);
        const view = camera.viewMatrix();

        // Cube
        lighting_shader.use();

        lighting_shader.setVec3("viewPos", camera.position);

        lighting_shader.seti32("material.diffuse", 0);
        lighting_shader.seti32("material.specular", 1);
        lighting_shader.setf32("material.shininess", 32.0);

        lighting_shader.setVec3("dirLight.direction", .{ -0.2, -1.0, -0.2 });
        lighting_shader.setVec3("dirLight.ambient", .{ 0.05, 0.05, 0.05 });
        lighting_shader.setVec3("dirLight.diffuse", .{ 0.4, 0.4, 0.4 });
        lighting_shader.setVec3("dirLight.specular", .{ 0.5, 0.5, 0.5 });

        inline for (point_light_positions) |point_light_position, i| {
            const prefix = comptime std.fmt.comptimePrint("pointLights[{}].", .{i});

            lighting_shader.setVec3(prefix ++ "position", point_light_position);
            lighting_shader.setVec3(prefix ++ "ambient", .{ 0.05, 0.05, 0.05 });
            lighting_shader.setVec3(prefix ++ "diffuse", .{ 0.8, 0.8, 0.8 });
            lighting_shader.setVec3(prefix ++ "specular", .{ 1.0, 1.0, 1.0 });
            lighting_shader.setf32(prefix ++ "constant", 1.0);
            lighting_shader.setf32(prefix ++ "linear", 0.09);
            lighting_shader.setf32(prefix ++ "quadratic", 0.032);
        }

        lighting_shader.setVec3("spotLight.position", camera.position);
        lighting_shader.setVec3("spotLight.direction", camera.front());
        lighting_shader.setVec3("spotLight.ambient", .{ 0.0, 0.0, 0.0 });
        lighting_shader.setVec3("spotLight.diffuse", .{ 1.0, 1.0, 1.0 });
        lighting_shader.setVec3("spotLight.specular", .{ 1.0, 1.0, 1.0 });
        lighting_shader.setf32("spotLight.constant", 1.0);
        lighting_shader.setf32("spotLight.linear", 0.09);
        lighting_shader.setf32("spotLight.quadratic", 0.032);
        lighting_shader.setf32("spotLight.cutOff", math.cos(@as(f32, 12.5 * tau / 360.0)));
        lighting_shader.setf32("spotLight.outerCutOff", math.cos(@as(f32, 15 * tau / 360.0)));

        lighting_shader.setMat("projection", projection);
        lighting_shader.setMat("view", view);

        cube_vao.bind();

        for (cube_positions) |position, i| {
            const angle = 20.0 * @intToFloat(f32, i);

            var model = math.translationV(position);
            model = math.mul(math.matFromAxisAngle(.{ 1.0, 0.3, 0.5 }, angle), model);
            lighting_shader.setMat("model", model);
            gl.drawArrays(.triangles, 0, 36);
        }

        // Lamp object
        light_cube_shader.use();
        light_cube_vao.bind();
        light_cube_shader.setMat("projection", projection);
        light_cube_shader.setMat("view", view);

        for (point_light_positions) |point_light_position| {
            var model = math.translationV(point_light_position);
            model = math.mul(math.scalingV(math.f32x4s(0.2)), model);

            light_cube_shader.setMat("model", model);
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

fn textureFromImage(image: Image, unit: gl.TextureUnit) !gl.Texture {
    const format: gl.PixelFormat = switch (image.channels) {
        1 => .red,
        3 => .rgb,
        4 => .rgba,
        else => return error.ImageFormatError,
    };

    const texture = gl.genTexture();
    gl.activeTexture(unit);
    texture.bind(.@"2d");
    gl.texParameter(.@"2d", .wrap_s, .repeat);
    gl.texParameter(.@"2d", .wrap_t, .repeat);
    gl.texParameter(.@"2d", .min_filter, .linear);
    gl.texParameter(.@"2d", .mag_filter, .linear);
    gl.textureImage2D(.@"2d", 0, format, image.width, image.height, format, .unsigned_byte, image.data);
    gl.generateMipmap(.@"2d");

    return texture;
}
