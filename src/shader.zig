const std = @import("std");
const gl = @import("zgl");
const math = @import("zmath");

const allocator = std.heap.c_allocator;

pub const Shader = struct {
    program: gl.Program,

    pub fn init(comptime vertex_file: []const u8, comptime fragment_file: []const u8, comptime geometry_file: ?[]const u8) !Shader {
        const vertex_shader = try compileShader(vertex_file, .vertex);
        defer gl.deleteShader(vertex_shader);

        const fragment_shader = try compileShader(fragment_file, .fragment);
        defer gl.deleteShader(fragment_shader);

        var geometry_shader: ?gl.Shader = null;
        if (geometry_file) |gf| {
            geometry_shader = try compileShader(gf, .geometry);
        }
        defer if (geometry_shader) |gs| gl.deleteShader(gs);

        const program = gl.createProgram();
        errdefer gl.deleteProgram(program);
        gl.attachShader(program, vertex_shader);
        gl.attachShader(program, fragment_shader);
        if (geometry_shader) |gs| gl.attachShader(program, gs);
        gl.linkProgram(program);

        if (gl.getProgram(program, .link_status) == 0) {
            const log = try gl.getProgramInfoLog(program, allocator);
            defer allocator.free(log);
            std.debug.print("Error linking program:\n{s}\n", .{log});
            return error.ShaderCompilationError;
        }

        return Shader{ .program = program };
    }

    fn compileShader(comptime filename: []const u8, shader_type: gl.ShaderType) !gl.Shader {
        const shader = gl.createShader(shader_type);
        errdefer gl.deleteShader(shader);
        gl.shaderSource(shader, 1, &.{@embedFile(filename)});
        gl.compileShader(shader);
        if (gl.getShader(shader, .compile_status) == 0) {
            const log = try gl.getShaderInfoLog(shader, allocator);
            defer allocator.free(log);
            std.debug.print("Error compiling {s}:\n{s}\n", .{ filename, log });
            return error.ShaderCompilationError;
        }
        return shader;
    }

    pub fn deinit(shader: Shader) void {
        gl.deleteProgram(shader.program);
    }

    pub fn use(shader: Shader) void {
        gl.useProgram(shader.program);
    }

    pub fn setf32(shader: Shader, name: [:0]const u8, value: f32) void {
        const location = gl.getUniformLocation(shader.program, name) orelse return;
        gl.uniform1f(location, value);
    }

    pub fn setu32(shader: Shader, name: [:0]const u8, value: u32) void {
        const location = gl.getUniformLocation(shader.program, name) orelse return;
        gl.uniform1ui(location, value);
    }

    pub fn seti32(shader: Shader, name: [:0]const u8, value: i32) void {
        const location = gl.getUniformLocation(shader.program, name) orelse return;
        gl.uniform1i(location, value);
    }

    pub fn setMat(shader: Shader, name: [:0]const u8, value: math.Mat) void {
        const location = gl.getUniformLocation(shader.program, name) orelse return;
        gl.uniformMatrix4fv(location, false, &.{math.matToArray(value)});
    }

    pub fn setVec(shader: Shader, name: [:0]const u8, value: math.Vec) void {
        const location = gl.getUniformLocation(shader.program, name) orelse return;
        gl.uniform4f(location, value[0], value[1], value[2], value[3]);
    }

    pub fn setVec2(shader: Shader, name: [:0]const u8, value: math.Vec) void {
        const location = gl.getUniformLocation(shader.program, name) orelse return;
        gl.uniform2f(location, value[0], value[1]);
    }

    pub fn setVec3(shader: Shader, name: [:0]const u8, value: math.Vec) void {
        const location = gl.getUniformLocation(shader.program, name) orelse return;
        gl.uniform3f(location, value[0], value[1], value[2]);
    }
};
