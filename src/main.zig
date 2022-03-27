const builtin = @import("builtin");
const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const math = @import("zmath");
const tau = std.math.tau;

const Camera = @import("./camera.zig").Camera;
const Model = @import("./model.zig").Model;
const Shader = @import("./shader.zig").Shader;

const allocator = std.heap.c_allocator;
const wireframe_mode = false;

var camera = Camera.init(
    math.f32x4(0.0, 0.0, 155.0, 1.0),
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

    const planet_shader = try Shader.init("planet.vert", "shader.frag", null);
    defer planet_shader.deinit();

    const asteroid_shader = try Shader.init("asteroid.vert", "shader.frag", null);
    defer asteroid_shader.deinit();

    const planet = try Model.init(allocator, "assets/planet/planet.obj");
    defer planet.deinit();

    const rock = try Model.init(allocator, "assets/rock/rock.obj");
    defer rock.deinit();

    const count = 100_000;

    const buffer = gl.genBuffer();
    defer gl.deleteBuffer(buffer);
    gl.bindBuffer(.array_buffer, buffer);
    gl.bufferUninitialized(.array_buffer, [16]f32, count, .static_draw);

    const rng = std.rand.DefaultPrng.init(@bitCast(u64, glfw.getTime())).random();

    const radius = 150.0;
    const offset = 25.0;
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const angle = @intToFloat(f32, i) / @intToFloat(f32, count) * 360.0;
        var model = math.translation(
            math.sin(angle) * radius + rng.float(f32) * 2.0 * offset - offset,
            0.04 * (rng.float(f32) * 2.0 * offset - offset),
            math.cos(angle) * radius + rng.float(f32) * 2.0 * offset - offset,
        );

        const scale = rng.float(f32) * 0.2 + 0.05;
        model = math.mul(math.scaling(scale, scale, scale), model);

        const rotation = rng.float(f32) * 360.0;
        model = math.mul(math.matFromAxisAngle(.{ 0.4, 0.6, 0.8, 1.0 }, rotation), model);

        gl.bufferSubData(.array_buffer, @sizeOf([16]f32) * i, [16]f32, &.{math.matToArray(model)});
    }

    for (rock.meshes.items) |mesh| {
        const vao = mesh.vao;
        gl.bindVertexArray(vao);
        defer gl.bindVertexArray(.none);

        i = 0;
        while (i < 4) : (i += 1) {
            gl.enableVertexAttribArray(3 + i);
            gl.vertexAttribPointer(3 + i, 4, .float, false, @sizeOf([16]f32), i * @sizeOf([4]f32));
            gl.vertexAttribDivisor(3 + i, 1);
        }
    }

    while (!window.shouldClose()) {
        const current_frame = @floatCast(f32, glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;

        processInput(window);

        gl.clearColor(0.05, 0.05, 0.05, 1.0);
        gl.clear(.{ .color = true, .depth = true });

        const projection = math.perspectiveFovRh(camera.zoom * tau / 360.0, 800.0 / 600.0, 0.1, 1000.0);
        const view = camera.viewMatrix();
        asteroid_shader.use();
        asteroid_shader.setMat("projection", projection);
        asteroid_shader.setMat("view", view);

        planet_shader.use();
        planet_shader.setMat("projection", projection);
        planet_shader.setMat("view", view);

        var model = math.translation(0.0, -3.0, 0.0);
        model = math.mul(math.scaling(4.0, 4.0, 4.0), model);
        planet_shader.setMat("model", model);
        planet.draw(planet_shader);

        asteroid_shader.use();
        asteroid_shader.seti32("texture_diffuse1", 0);
        gl.bindTexture(.@"2d", rock.loaded_textures.items[0].texture);
        for (rock.meshes.items) |mesh| {
            gl.bindVertexArray(mesh.vao);
            gl.drawElementsInstanced(.triangles, mesh.indices.len, .u32, 0, count);
        }

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
