const std = @import("std");
const gl = @import("zgl");
const assimp = @cImport({
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});

const Shader = @import("./shader.zig").Shader;

const Vertex = struct {
    position: [3]f32,
    normal: [3]f32,
    tex_coords: [2]f32,
};

const Texture = struct {
    texture: gl.Texture,
    type: enum { diffuse, specular },
};

const Mesh = struct {
    vertices: []const Vertex,
    indices: []const i32,
    textures: []const Texture,

    vao: gl.VertexArray,
    vbo: gl.Buffer,
    ebo: gl.Buffer,

    pub fn init(vertices: []const Vertex, indices: []const i32, textures: []const Texture) Mesh {
        var mesh = Mesh{
            .vertices = vertices,
            .indices = indices,
            .textures = textures,
            .vao = gl.genVertexArray(),
            .vbo = gl.genBuffer(),
            .ebo = gl.genBuffer,
        };

        mesh.vao.bind();
        defer gl.bindVertexArray(.invalid);

        mesh.vbo.bind(.array_buffer);
        gl.bufferData(.array_buffer, Vertex, vertices, .static_draw);

        mesh.ebo.bind(.element_array_buffer);
        gl.bufferData(.element_array_buffer, i32, indices, .static_copy);

        // Vertex
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(0, 3, .float, false, @sizeOf(Vertex), 0);

        // Vertex Normals
        gl.enableVertexAttribArray(1);
        gl.vertexAttribPointer(1, 3, .float, false, @sizeOf(Vertex), @offsetOf(Vertex, "normal"));

        // Vertex Texture Coords
        gl.enableVertexAttribArray(2);
        gl.vertexAttribPointer(2, 2, .float, false, @sizeOf(Vertex), @offsetOf(Vertex, "tex_coords"));

        return mesh;
    }

    pub fn deinit(mesh: Mesh) void {
        mesh.ebo.delete();
        mesh.vbo.delete();
        mesh.vao.delete();
    }

    pub fn draw(mesh: Mesh, shader: Shader) !void {
        var diffuse = 1;
        var specular = 1;

        for (mesh.textures) |texture, i| {
            gl.activeTexture(.texture_0 + i);
            var buffer: [50]u8 = undefined;

            const name = switch (texture.type) {
                .diffuse => blk: {
                    defer diffuse += 1;
                    break :blk try std.fmt.bufPrintZ(&buffer, "material.texture_diffuse{}", .{diffuse});
                },
                .specular => blk: {
                    defer specular += 1;
                    break :blk try std.fmt.bufPrintZ(&buffer, "material.texture_specular{}", .{specular});
                },
            };

            shader.seti32(name, i);
            texture.texture.bind(.@"2d");
        }

        gl.activeTexture(.texture_0);

        mesh.vao.bind();
        defer gl.bindVertexArray(.invalid);
        gl.drawElements(.triangles, mesh.indices.len, .unsigned_int, 0);
    }
};
