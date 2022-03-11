const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");

pub fn main() !void {
    try glfw.init(.{});
    defer glfw.terminate();

    const window = try glfw.Window.create(800, 600, "Learn OpenGL", null, null, .{
        .context_version_major = 3,
        .context_version_minor = 3,
        .opengl_profile = .opengl_core_profile,
    });
    defer window.destroy();
    try glfw.makeContextCurrent(window);
    window.setFramebufferSizeCallback(framebufferSizeCallback);

    try gl.init(glfw.getProcAddress);

    const shader_program = blk: {
        const vertex_shader = gl.createShader(.vertex);
        defer vertex_shader.delete();
        vertex_shader.source(1, &.{@embedFile("triangle.vert")});
        vertex_shader.compile();
        if (vertex_shader.get(.compile_status) == 0) return error.ShaderCompilationError;

        const fragment_shader = gl.createShader(.fragment);
        defer fragment_shader.delete();
        fragment_shader.source(1, &.{@embedFile("triangle.frag")});
        fragment_shader.compile();
        if (fragment_shader.get(.compile_status) == 0) return error.ShaderCompilationError;

        const program = gl.createProgram();
        program.attach(vertex_shader);
        program.attach(fragment_shader);
        program.link();

        if (program.get(.link_status) == 0) return error.ProgramLinkError;

        break :blk program;
    };
    defer shader_program.delete();

    const vertices = [_]f32{
        -0.5, -0.5, 0.0,
        0.5,  -0.5, 0.0,
        0.0,  0.5,  0.0,
    };

    const vao = gl.genVertexArray();
    defer vao.delete();

    const vbo = gl.genBuffer();
    defer vbo.delete();

    vao.bind();
    vbo.bind(.array_buffer);
    gl.bufferData(.array_buffer, f32, &vertices, .static_draw);
    gl.vertexAttribPointer(0, 3, .float, false, 3 * @sizeOf(f32), 0);
    gl.enableVertexAttribArray(0);

    // gl.bindBuffer(.invalid, .array_buffer);
    // gl.bindVertexArray(.invalid);

    while (!window.shouldClose()) {
        processInput(window);

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(.{ .color = true });

        shader_program.use();
        vao.bind();
        gl.drawArrays(.triangles, 0, 3);

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
