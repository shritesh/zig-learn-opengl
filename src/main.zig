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

    const fragment_shader1 = gl.createShader(.fragment);
    fragment_shader1.source(1, &.{@embedFile("triangle1.frag")});
    fragment_shader1.compile();
    if (fragment_shader1.get(.compile_status) == 0) return error.ShaderCompilationError;

    const fragment_shader2 = gl.createShader(.fragment);
    fragment_shader2.source(1, &.{@embedFile("triangle2.frag")});
    fragment_shader2.compile();
    if (fragment_shader2.get(.compile_status) == 0) return error.ShaderCompilationError;

    const program1 = gl.createProgram();
    defer program1.delete();
    program1.attach(vertex_shader);
    program1.attach(fragment_shader1);
    program1.link();
    if (program1.get(.link_status) == 0) return error.ProgramLinkError;

    const program2 = gl.createProgram();
    defer program2.delete();
    program2.attach(vertex_shader);
    program2.attach(fragment_shader2);
    program2.link();
    if (program2.get(.link_status) == 0) return error.ProgramLinkError;

    vertex_shader.delete();
    fragment_shader1.delete();
    fragment_shader2.delete();

    const vertices = [_]f32{
        -0.75, -0.25, 0.0,
        -0.25, -0.25, 0.0,
        -0.5,  0.5,   0.0,

        0,     -0.25, 0.0,
        0.5,   -0.25, 0.0,
        0.25,  0.5,   0.0,
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

        program1.use();
        gl.drawArrays(.triangles, 0, 3);

        program2.use();
        gl.drawArrays(.triangles, 3, 3);

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
