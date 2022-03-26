const builtin = @import("builtin");
const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const math = @import("zmath");

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
        .cocoa_retina_framebuffer = false,
    });
    defer window.destroy();

    try glfw.makeContextCurrent(window);
    try gl.load(glfw.getProcAddress);

    window.setFramebufferSizeCallback(framebufferSizeCallback);
    if (wireframe_mode) gl.polygonMode(.front_and_back, .line);

    const shader = try Shader.init("shader.vert", "shader.frag", "shader.geom");
    defer shader.deinit();

    const points = [_]f32{
        -0.5, 0.5, 1.0, 0.0, 0.0, // top-left
        0.5, 0.5, 0.0, 1.0, 0.0, // top-right
        0.5, -0.5, 0.0, 0.0, 1.0, // bottom-right
        -0.5, -0.5, 1.0, 1.0, 0.0, // bottom-left
    };

    const vao = gl.genVertexArray();
    defer gl.deleteVertexArray(vao);

    gl.bindVertexArray(vao);

    const vbo = gl.genBuffer();
    defer gl.deleteBuffer(vbo);

    gl.bindBuffer(.array_buffer, vbo);
    gl.bufferData(.array_buffer, f32, &points, .static_draw);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, .float, false, 5 * @sizeOf(f32), 0);

    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 3, .float, false, 5 * @sizeOf(f32), 2 * @sizeOf(f32));

    shader.use();

    while (!window.shouldClose()) {
        processInput(window);

        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(.{
            .color = true,
        });

        gl.drawArrays(.points, 0, 4);

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
