const std = @import("std");
const gl = @import("zgl");
const math = @import("zmath");

const allocator = std.heap.c_allocator;

pub const Shader = struct {
    program: gl.Program,

    pub fn init(comptime vertex_file: []const u8, comptime fragment_file: []const u8) !Shader {
        const vertex_src = @embedFile(vertex_file);
        const fragment_src = @embedFile(fragment_file);

        const vertex_shader = gl.createShader(.vertex);
        defer gl.deleteShader(vertex_shader);
        gl.shaderSource(vertex_shader, 1, &.{vertex_src});
        gl.compileShader(vertex_shader);
        if (gl.getShader(vertex_shader, .compile_status) == 0) {
            const log = try gl.getShaderInfoLog(vertex_shader, allocator);
            defer allocator.free(log);
            std.debug.print("Error compiling {s}:\n{s}\n", .{ vertex_file, log });
            return error.ShaderCompilationError;
        }

        const fragment_shader = gl.createShader(.fragment);
        defer gl.deleteShader(fragment_shader);
        gl.shaderSource(fragment_shader, 1, &.{fragment_src});
        gl.compileShader(fragment_shader);
        if (gl.getShader(fragment_shader, .compile_status) == 0) {
            const log = try gl.getShaderInfoLog(fragment_shader, allocator);
            defer allocator.free(log);
            std.debug.print("Error compiling {s}:\n{s}\n", .{ fragment_file, log });
            return error.ShaderCompilationError;
        }

        const program = gl.createProgram();
        errdefer gl.deleteProgram(program);
        gl.attachShader(program, vertex_shader);
        gl.attachShader(program, fragment_shader);
        gl.linkProgram(program);

        if (gl.getProgram(program, .link_status) == 0) {
            const log = try gl.getProgramInfoLog(program, allocator);
            defer allocator.free(log);
            std.debug.print("Error linking {s} and {s}:\n{s}\n", .{ vertex_file, fragment_file, log });
            return error.ShaderCompilationError;
        }

        return Shader{ .program = program };
    }

    pub fn deinit(shader: Shader) void {
        gl.deleteProgram(shader.program);
    }

    pub fn use(shader: Shader) void {
        gl.useProgram(shader.program);
    }

    pub fn setf32(shader: Shader, name: [:0]const u8, value: f32) void {
        const location = gl.getUniformLocation(shader.program, name).?;
        gl.uniform1f(location, value);
    }

    pub fn setu32(shader: Shader, name: [:0]const u8, value: u32) void {
        const location = gl.getUniformLocation(shader.program, name).?;
        gl.uniform1ui(location, value);
    }

    pub fn seti32(shader: Shader, name: [:0]const u8, value: i32) void {
        const location = gl.getUniformLocation(shader.program, name).?;
        gl.uniform1i(location, value);
    }

    pub fn setMat(shader: Shader, name: [:0]const u8, value: math.Mat) void {
        const location = gl.getUniformLocation(shader.program, name).?;
        gl.uniformMatrix4fv(location, false, &.{math.matToArray(value)});
    }

    pub fn setVec3(shader: Shader, name: [:0]const u8, value: math.Vec) void {
        const location = gl.getUniformLocation(shader.program, name).?;
        gl.uniform3f(location, value[0], value[1], value[2]);
    }

    pub fn setVec(shader: Shader, name: [:0]const u8, value: math.Vec) void {
        const location = gl.getUniformLocation(shader.program, name).?;
        gl.uniform4f(location, value[0], value[1], value[2], value[3]);
    }
};
