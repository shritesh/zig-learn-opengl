const gl = @import("zgl");

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

    pub fn deinit(self: Shader) void {
        self.program.delete();
    }

    pub fn use(self: Shader) void {
        self.program.use();
    }

    pub fn set(self: Shader, name: [:0]const u8, comptime T: type, value: T) void {
        const location = self.program.uniformLocation(name);

        switch (T) {
            f32 => self.program.uniform1f(location, value),
            else => @compileError("Invalid type"),
        }
    }
};
