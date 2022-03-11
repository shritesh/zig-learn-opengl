const builtin = @import("builtin");
const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");

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

    const vertex_shader = gl.createShader(.vertex);
    vertex_shader.source(1, &.{@embedFile("triangle.vert")});
    vertex_shader.compile();
    if (vertex_shader.get(.compile_status) == 0) return error.ShaderCompilationError;

    var fragment_shaders: [2]gl.Shader = undefined;
    inline for (.{ @embedFile("triangle1.frag"), @embedFile("triangle2.frag") }) |src, i| {
        fragment_shaders[i] = gl.createShader(.fragment);
        fragment_shaders[i].source(1, &.{src});
        fragment_shaders[i].compile();
        if (fragment_shaders[i].get(.compile_status) == 0) return error.ShaderCompilationError;
    }

    var programs: [2]gl.Program = undefined;
    for (programs) |*program, i| {
        program.* = gl.createProgram();
        errdefer program.delete();
        program.attach(vertex_shader);
        program.attach(fragment_shaders[i]);
        program.link();
        if (program.get(.link_status) == 0) return error.ProgramLinkError;
    }

    vertex_shader.delete();
    for (fragment_shaders) |fragment_shader| {
        fragment_shader.delete();
    }
    defer {
        for (programs) |program| {
            program.delete();
        }
    }

    const vertices = [2][9]f32{ .{
        -0.75, -0.25, 0.0,
        -0.25, -0.25, 0.0,
        -0.5,  0.5,   0.0,
    }, .{
        0,    -0.25, 0.0,
        0.5,  -0.25, 0.0,
        0.25, 0.5,   0.0,
    } };

    var vaos: [2]gl.VertexArray = undefined;
    gl.genVertexArrays(&vaos);
    defer gl.deleteVertexArrays(&vaos);

    var vbos: [2]gl.Buffer = undefined;
    gl.genBuffers(&vbos);
    defer gl.deleteBuffers(&vbos);

    for (vaos) |vao, i| {
        vao.bind();

        vbos[i].bind(.array_buffer);
        gl.bufferData(.array_buffer, f32, &vertices[i], .static_draw);

        gl.vertexAttribPointer(0, 3, .float, false, 3 * @sizeOf(f32), 0);
        gl.enableVertexAttribArray(0);
    }

    if (wireframe_mode) gl.polygonMode(.front_and_back, .line);

    while (!window.shouldClose()) {
        processInput(window);

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(.{ .color = true });

        for (programs) |program, i| {
            program.use();
            vaos[i].bind();
            gl.drawArrays(.triangles, 0, 3);
        }

        try window.swapBuffers();
        try glfw.pollEvents();
    }
}

fn processInput(window: glfw.Window) void {
    if (window.getKey(.escape) == .press) {
        window.setShouldClose(true);
    }
}

fn framebufferSizeCallback(_: glfw.Window, width: u32, height: u32) void {
    gl.viewport(0, 0, width, height);
}
