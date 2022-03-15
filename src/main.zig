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

var frame_counter: usize = 0;

var light_pos = math.f32x4(1.2, 1.0, 2.0, 1.0);
var current_material: u32 = 0;

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

    const lighting_shader = try Shader.init("lighting.vert", "lighting.frag");
    defer lighting_shader.deinit();

    const light_cube_shader = try Shader.init("light_cube.vert", "light_cube.frag");
    defer light_cube_shader.deinit();

    const vertices = [_]f32{
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

    const cube_vao = gl.genVertexArray();
    defer cube_vao.delete();

    cube_vao.bind();

    const vbo = gl.genBuffer();
    defer vbo.delete();

    vbo.bind(.array_buffer);
    gl.bufferData(.array_buffer, f32, &vertices, .static_draw);

    gl.vertexAttribPointer(0, 3, .float, false, 6 * @sizeOf(f32), 0);
    gl.enableVertexAttribArray(0);

    gl.vertexAttribPointer(1, 3, .float, false, 6 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.enableVertexAttribArray(1);

    const light_cube_vao = gl.genVertexArray();
    defer light_cube_vao.delete();

    light_cube_vao.bind();

    vbo.bind(.array_buffer);

    gl.vertexAttribPointer(0, 3, .float, false, 6 * @sizeOf(f32), 0);
    gl.enableVertexAttribArray(0);

    while (!window.shouldClose()) {
        const current_frame = @floatCast(f32, glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;

        frame_counter +%= 1;
        if (frame_counter % 100 == 0) {
            current_material += 1;
            if (current_material == materials.len) current_material = 0;
            try window.setTitle(materials[current_material].name);
        }

        processInput(window);

        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(.{ .color = true, .depth = true });

        const projection = math.perspectiveFovRh(camera.zoom * tau / 360.0, 800.0 / 600.0, 0.1, 100.0);
        const view = camera.viewMatrix();
        var model = math.identity();

        // Cube
        lighting_shader.use();

        lighting_shader.setVec3("viewPos", camera.position);

        lighting_shader.setVec3("material.ambient", materials[current_material].ambient);
        lighting_shader.setVec3("material.diffuse", materials[current_material].diffuse);
        lighting_shader.setVec3("material.specular", materials[current_material].specular);
        lighting_shader.setf32("material.shininess", materials[current_material].shininess * 128.0);

        lighting_shader.setVec3("light.position", light_pos);
        lighting_shader.setVec3("light.ambient", .{ 1.0, 1.0, 1.0 });
        lighting_shader.setVec3("light.diffuse", .{ 1.0, 1.0, 1.0 });
        lighting_shader.setVec3("light.specular", .{ 1.0, 1.0, 1.0 });

        lighting_shader.setMat("projection", projection);
        lighting_shader.setMat("view", view);
        lighting_shader.setMat("model", model);

        cube_vao.bind();
        gl.drawArrays(.triangles, 0, 36);

        // Lamp object
        light_cube_shader.use();

        model = math.translationV(light_pos);
        model = math.mul(math.scalingV(math.f32x4s(0.2)), model);

        light_cube_shader.setMat("projection", projection);
        light_cube_shader.setMat("view", view);
        light_cube_shader.setMat("model", model);

        light_cube_vao.bind();
        gl.drawArrays(.triangles, 0, 36);

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

const Material = struct {
    name: [:0]const u8,
    ambient: math.Vec,
    diffuse: math.Vec,
    specular: math.Vec,
    shininess: f32,
};

const materials = [_]Material{
    .{ .name = "emerald", .ambient = .{ 0.0215, 0.1745, 0.0215 }, .diffuse = .{ 0.07568, 0.61424, 0.07568 }, .specular = .{ 0.633, 0.727811, 0.633 }, .shininess = 0.6 },
    .{ .name = "jade", .ambient = .{ 0.135, 0.2225, 0.1575 }, .diffuse = .{ 0.54, 0.89, 0.63 }, .specular = .{ 0.316228, 0.316228, 0.316228 }, .shininess = 0.1 },
    .{ .name = "obsidian", .ambient = .{ 0.05375, 0.05, 0.06625 }, .diffuse = .{ 0.18275, 0.17, 0.22525 }, .specular = .{ 0.332741, 0.328634, 0.346435 }, .shininess = 0.3 },
    .{ .name = "pearl", .ambient = .{ 0.25, 0.20725, 0.20725 }, .diffuse = .{ 1.0, 0.829, 0.829 }, .specular = .{ 0.296648, 0.296648, 0.296648 }, .shininess = 0.088 },
    .{ .name = "ruby", .ambient = .{ 0.1745, 0.01175, 0.01175 }, .diffuse = .{ 0.61424, 0.04136, 0.04136 }, .specular = .{ 0.727811, 0.626959, 0.626959 }, .shininess = 0.6 },
    .{ .name = "turquoise", .ambient = .{ 0.1, 0.18725, 0.1745 }, .diffuse = .{ 0.396, 0.74151, 0.69102 }, .specular = .{ 0.297254, 0.30829, 0.306678 }, .shininess = 0.1 },
    .{ .name = "brass", .ambient = .{ 0.329412, 0.223529, 0.027451 }, .diffuse = .{ 0.780392, 0.568627, 0.113725 }, .specular = .{ 0.992157, 0.941176, 0.807843 }, .shininess = 0.21794872 },
    .{ .name = "bronze", .ambient = .{ 0.2125, 0.1275, 0.054 }, .diffuse = .{ 0.714, 0.4284, 0.18144 }, .specular = .{ 0.393548, 0.271906, 0.166721 }, .shininess = 0.2 },
    .{ .name = "chrome", .ambient = .{ 0.25, 0.25, 0.25 }, .diffuse = .{ 0.4, 0.4, 0.4 }, .specular = .{ 0.774597, 0.774597, 0.774597 }, .shininess = 0.6 },
    .{ .name = "copper", .ambient = .{ 0.19125, 0.0735, 0.0225 }, .diffuse = .{ 0.7038, 0.27048, 0.0828 }, .specular = .{ 0.256777, 0.137622, 0.086014 }, .shininess = 0.1 },
    .{ .name = "gold", .ambient = .{ 0.24725, 0.1995, 0.0745 }, .diffuse = .{ 0.75164, 0.60648, 0.22648 }, .specular = .{ 0.628281, 0.555802, 0.366065 }, .shininess = 0.4 },
    .{ .name = "silver", .ambient = .{ 0.19225, 0.19225, 0.19225 }, .diffuse = .{ 0.50754, 0.50754, 0.50754 }, .specular = .{ 0.508273, 0.508273, 0.508273 }, .shininess = 0.4 },
    .{ .name = "black plastic", .ambient = .{ 0.0, 0.0, 0.0 }, .diffuse = .{ 0.01, 0.01, 0.01 }, .specular = .{ 0.50, 0.50, 0.50 }, .shininess = 0.25 },
    .{ .name = "cyan plastic", .ambient = .{ 0.0, 0.1, 0.06 }, .diffuse = .{ 0.0, 0.50980392, 0.50980392 }, .specular = .{ 0.50196078, 0.50196078, 0.50196078 }, .shininess = 0.25 },
    .{ .name = "green plastic", .ambient = .{ 0.0, 0.0, 0.0 }, .diffuse = .{ 0.1, 0.35, 0.1 }, .specular = .{ 0.45, 0.55, 0.45 }, .shininess = 0.25 },
    .{ .name = "red plastic", .ambient = .{ 0.0, 0.0, 0.0 }, .diffuse = .{ 0.5, 0.0, 0.0 }, .specular = .{ 0.7, 0.6, 0.6 }, .shininess = 0.25 },
    .{ .name = "white plastic", .ambient = .{ 0.0, 0.0, 0.0 }, .diffuse = .{ 0.55, 0.55, 0.55 }, .specular = .{ 0.70, 0.70, 0.70 }, .shininess = 0.25 },
    .{ .name = "yellow plastic", .ambient = .{ 0.0, 0.0, 0.0 }, .diffuse = .{ 0.5, 0.5, 0.0 }, .specular = .{ 0.60, 0.60, 0.50 }, .shininess = 0.25 },
    .{ .name = "black rubber", .ambient = .{ 0.02, 0.02, 0.02 }, .diffuse = .{ 0.01, 0.01, 0.01 }, .specular = .{ 0.4, 0.4, 0.4 }, .shininess = 0.078125 },
    .{ .name = "cyan rubber", .ambient = .{ 0.0, 0.05, 0.05 }, .diffuse = .{ 0.4, 0.5, 0.5 }, .specular = .{ 0.04, 0.7, 0.7 }, .shininess = 0.078125 },
    .{ .name = "green rubber", .ambient = .{ 0.0, 0.05, 0.0 }, .diffuse = .{ 0.4, 0.5, 0.4 }, .specular = .{ 0.04, 0.7, 0.04 }, .shininess = 0.078125 },
    .{ .name = "red rubber", .ambient = .{ 0.05, 0.0, 0.0 }, .diffuse = .{ 0.5, 0.4, 0.4 }, .specular = .{ 0.7, 0.04, 0.04 }, .shininess = 0.078125 },
    .{ .name = "white rubber", .ambient = .{ 0.05, 0.05, 0.05 }, .diffuse = .{ 0.5, 0.5, 0.5 }, .specular = .{ 0.7, 0.7, 0.7 }, .shininess = 0.078125 },
    .{ .name = "yellow rubber", .ambient = .{ 0.05, 0.05, 0.0 }, .diffuse = .{ 0.5, 0.5, 0.4 }, .specular = .{ 0.7, 0.7, 0.04 }, .shininess = 0.078125 },
};
