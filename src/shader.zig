const gl = @import("zgl");
const math = @import("zmath");

pub const Shader = struct {
    program: gl.Program,

    pub fn init(vertex_src: []const u8, fragment_src: []const u8) !Shader {
        const vertex_shader = gl.createShader(.vertex);
        defer vertex_shader.delete();
        vertex_shader.source(1, &.{vertex_src});
        vertex_shader.compile();
        if (vertex_shader.get(.compile_status) == 0) return error.ShaderCompilationError;

        const fragment_shader = gl.createShader(.fragment);
        defer fragment_shader.delete();
        fragment_shader.source(1, &.{fragment_src});
        fragment_shader.compile();
        if (fragment_shader.get(.compile_status) == 0) return error.ShaderCompilationError;

        const program = gl.createProgram();
        errdefer program.delete();
        program.attach(vertex_shader);
        program.attach(fragment_shader);
        program.link();

        if (program.get(.link_status) == 0) return error.ProgramLinkError;

        return Shader{ .program = program };
    }

    pub fn deinit(shader: Shader) void {
        shader.program.delete();
    }

    pub fn use(shader: Shader) void {
        shader.program.use();
    }

    pub fn setf32(shader: Shader, name: [:0]const u8, value: f32) void {
        const location = shader.program.uniformLocation(name);
        gl.uniform1f(location, value);
    }

    pub fn seti32(shader: Shader, name: [:0]const u8, value: i32) void {
        const location = shader.program.uniformLocation(name);
        gl.uniform1i(location, value);
    }

    pub fn setMat(shader: Shader, name: [:0]const u8, value: math.Mat) void {
        const location = shader.program.uniformLocation(name);
        gl.uniformMatrix4fv(location, false, &.{math.matToArray(value)});
    }

    pub fn setVec3(shader: Shader, name: [:0]const u8, value: math.Vec) void {
        const location = shader.program.uniformLocation(name);
        gl.uniform3f(location, value[0], value[1], value[2]);
    }

    pub fn setVec(shader: Shader, name: [:0]const u8, value: math.Vec) void {
        const location = shader.program.uniformLocation(name);
        gl.uniform4(location, value[0], value[1], value[2], value[3]);
    }
};
