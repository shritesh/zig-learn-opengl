const std = @import("std");
const glfw = @import("glfw");
const c = @cImport({
    @cInclude("glad/glad.h");
});

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

    // Maybe there's a way to make this cleaner
    if (c.gladLoadGLLoader(@ptrCast(fn ([*c]const u8) callconv(.C) ?*anyopaque, glfw.getProcAddress)) == 0)
        return error.GladLoadError;

    window.setFramebufferSizeCallback(framebufferSizeCallback);
    while (!window.shouldClose()) {
        processInput(window);

        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        try glfw.pollEvents();
        try window.swapBuffers();
    }
}

fn processInput(window: glfw.Window) void {
    if (window.getKey(.escape) == .press) {
        window.setShouldClose(true);
    }
}

fn framebufferSizeCallback(_: glfw.Window, width: u32, height: u32) void {
    c.glViewport(0, 0, @intCast(c_int, width), @intCast(c_int, height));
}
