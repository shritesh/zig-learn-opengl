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
        errdefer program.delete();
        program.attach(vertex_shader);
        program.attach(fragment_shader);
        program.link();

        if (program.get(.link_status) == 0) return error.ProgramLinkError;

        break :blk program;
    };
    defer shader_program.delete();

    const vertex_color_location = shader_program.uniformLocation("ourColor") orelse return error.UniformLocationError;

    const vertices = [_]f32{
        0.5, -0.5, 0.0, // bottom right
        -0.5, -0.5, 0.0, // bottom left
        0.0, 0.5, 0.0, // top
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

    if (wireframe_mode) gl.polygonMode(.front_and_back, .line);

    while (!window.shouldClose()) {
        processInput(window);

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(.{ .color = true });

        shader_program.use();

        const time_value = @floatCast(f32, glfw.getTime());
        const green_value = @sin(time_value) / 2.0 + 0.5;
        shader_program.uniform4f(vertex_color_location, 0.0, green_value, 0.0, 1.0);

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
