const std = @import("std");
const panic = std.debug.panic;

// TODO: Switch to zig API once we know more
const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});

pub fn main() void {
    if (c.glfwInit() == 0)
        panic("GLFW Init failed", .{});
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    const window = c.glfwCreateWindow(800, 600, "Learn OpenGL", null, null) orelse
        panic("Create window failed", .{});

    c.glfwMakeContextCurrent(window);

    if (c.gladLoadGLLoader(@ptrCast(fn ([*c]const u8) callconv(.C) ?*anyopaque, c.glfwGetProcAddress)) == 0)
        panic("GLAD Loading failed", .{});

    _ = c.glfwSetFramebufferSizeCallback(window, framebufferSizeCallback);

    while (c.glfwWindowShouldClose(window) == 0) {
        // input
        processInput(window);

        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        // events and swap buffers
        c.glfwPollEvents();
        c.glfwSwapBuffers(window);
    }
}

fn processInput(window: *c.GLFWwindow) void {
    if (c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS)
        c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
}

fn framebufferSizeCallback(_: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    c.glViewport(0, 0, width, height);
}
