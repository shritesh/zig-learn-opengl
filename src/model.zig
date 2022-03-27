const std = @import("std");
const gl = @import("zgl");
const c = @cImport({
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const Image = @import("./image.zig").Image;
const Shader = @import("./shader.zig").Shader;

const Vertex = struct {
    position: [3]f32,
    normal: [3]f32,
    tex_coords: [2]f32,
};

const TextureType = enum { diffuse, specular };

const Texture = struct {
    texture: gl.Texture,
    type: TextureType,
    name: []const u8,
};

const Mesh = struct {
    vertices: []const Vertex,
    indices: []const u32,
    textures: []const Texture,

    vao: gl.VertexArray,
    vbo: gl.Buffer,
    ebo: gl.Buffer,

    fn init(vertices: []const Vertex, indices: []const u32, textures: []const Texture) Mesh {
        var mesh = Mesh{
            .vertices = vertices,
            .indices = indices,
            .textures = textures,

            .vao = gl.genVertexArray(),
            .vbo = gl.genBuffer(),
            .ebo = gl.genBuffer(),
        };

        gl.bindVertexArray(mesh.vao);
        defer gl.bindVertexArray(.none);

        gl.bindBuffer(.array_buffer, mesh.vbo);
        gl.bufferData(.array_buffer, Vertex, vertices, .static_draw);

        gl.bindBuffer(.element_array_buffer, mesh.ebo);
        gl.bufferData(.element_array_buffer, u32, indices, .static_copy);

        // Vertex
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(0, 3, .float, false, @sizeOf(Vertex), @offsetOf(Vertex, "position"));

        // Vertex Normals
        gl.enableVertexAttribArray(1);
        gl.vertexAttribPointer(1, 3, .float, false, @sizeOf(Vertex), @offsetOf(Vertex, "normal"));

        // Vertex Texture Coords
        gl.enableVertexAttribArray(2);
        gl.vertexAttribPointer(2, 2, .float, false, @sizeOf(Vertex), @offsetOf(Vertex, "tex_coords"));

        return mesh;
    }

    pub fn deinit(mesh: Mesh) void {
        gl.deleteBuffer(mesh.ebo);
        gl.deleteBuffer(mesh.vbo);
        gl.deleteVertexArray(mesh.vao);
    }

    pub fn draw(mesh: Mesh, shader: Shader) void {
        var diffuse: u8 = 1;
        var specular: u8 = 1;

        for (mesh.textures) |texture, i| {
            gl.activeTexture(@intToEnum(gl.TextureUnit, @enumToInt(gl.TextureUnit.texture0) + i));
            var buffer: [50]u8 = undefined;

            const name = switch (texture.type) {
                .diffuse => blk: {
                    defer diffuse += 1;
                    break :blk std.fmt.bufPrintZ(&buffer, "texture_diffuse{}", .{diffuse}) catch unreachable;
                },
                .specular => blk: {
                    defer specular += 1;
                    break :blk std.fmt.bufPrintZ(&buffer, "texture_specular{}", .{specular}) catch unreachable;
                },
            };

            shader.seti32(name, @intCast(i32, i));
            gl.bindTexture(.@"2d", texture.texture);
        }

        gl.bindVertexArray(mesh.vao);
        defer gl.bindVertexArray(.none);
        gl.drawElements(.triangles, mesh.indices.len, .u32, 0);
    }
};

const ModelError = error{
    ModelImportError,
    TextureLoadError,
    OutOfMemory,
};

pub const Model = struct {
    arena_allocator: ArenaAllocator,
    meshes: ArrayList(Mesh),
    loaded_textures: ArrayList(Texture),
    directory: []const u8,

    pub fn init(backing_allocator: Allocator, path: [:0]const u8) ModelError!Model {
        var arena_allocator = ArenaAllocator.init(backing_allocator);
        var meshes = ArrayList(Mesh).init(arena_allocator.allocator());
        var loaded_textures = ArrayList(Texture).init(arena_allocator.allocator());
        var directory = if (std.mem.lastIndexOfScalar(u8, path, '/')) |last| path[0 .. last + 1] else "";

        var model = Model{
            .arena_allocator = arena_allocator,
            .meshes = meshes,
            .loaded_textures = loaded_textures,
            .directory = directory,
        };

        const scene = c.aiImportFile(path, c.aiProcess_Triangulate | c.aiProcess_FlipUVs) orelse return error.ModelImportError;
        defer c.aiReleaseImport(scene);

        if (scene.*.mFlags & c.AI_SCENE_FLAGS_INCOMPLETE != 0) return error.ModelImportError;
        const root_node = scene.*.mRootNode orelse return error.ModelImportError;

        try model.processNode(root_node, scene);

        return model;
    }

    pub fn deinit(model: Model) void {
        for (model.loaded_textures.items) |texture| {
            gl.deleteTexture(texture.texture);
        }

        for (model.meshes.items) |mesh| {
            mesh.deinit();
        }

        model.arena_allocator.deinit();
    }

    pub fn draw(model: Model, shader: Shader) void {
        for (model.meshes.items) |mesh| {
            mesh.draw(shader);
        }
    }

    fn processNode(model: *Model, node: *const c.aiNode, scene: *const c.aiScene) ModelError!void {
        if (node.mNumMeshes > 0) {
            for (node.mMeshes[0..node.mNumMeshes]) |meshIdx| {
                const mesh = scene.mMeshes[meshIdx];
                try model.processMesh(mesh, scene);
            }
        }

        if (node.mNumChildren > 0) {
            for (node.mChildren[0..node.mNumChildren]) |child| {
                try model.processNode(child, scene);
            }
        }
    }

    fn processMesh(model: *Model, mesh: *const c.aiMesh, scene: *const c.aiScene) ModelError!void {
        var vertices = ArrayList(Vertex).init(model.arena_allocator.allocator());
        var indices = ArrayList(u32).init(model.arena_allocator.allocator());
        var textures = ArrayList(Texture).init(model.arena_allocator.allocator());

        var i: usize = 0;
        while (i < mesh.mNumVertices) : (i += 1) {
            var vertex = Vertex{
                .position = .{ mesh.mVertices[i].x, mesh.mVertices[i].y, mesh.mVertices[i].z },
                .normal = .{ mesh.mNormals[i].x, mesh.mNormals[i].y, mesh.mNormals[i].z },
                .tex_coords = .{ 0.0, 0.0 },
            };

            if (mesh.mTextureCoords[0]) |texture_coords| {
                vertex.tex_coords[0] = texture_coords[i].x;
                vertex.tex_coords[1] = texture_coords[i].y;
            }

            try vertices.append(vertex);
        }

        i = 0;
        while (i < mesh.mNumFaces) : (i += 1) {
            const face = mesh.mFaces[i];
            var j: usize = 0;
            while (j < face.mNumIndices) : (j += 1) {
                try indices.append(face.mIndices[j]);
            }
        }
        if (mesh.mMaterialIndex > 0) {
            const material = scene.mMaterials[mesh.mMaterialIndex];
            try model.loadMaterialTextures(&textures, material, c.aiTextureType_DIFFUSE, .diffuse);
            try model.loadMaterialTextures(&textures, material, c.aiTextureType_SPECULAR, .specular);
        }

        try model.meshes.append(Mesh.init(vertices.items, indices.items, textures.items));
    }

    fn loadMaterialTextures(model: *Model, textures: *ArrayList(Texture), mat: *const c.aiMaterial, ai_type: c.aiTextureType, texture_type: TextureType) !void {
        var i: u32 = 0;
        while (i < c.aiGetMaterialTextureCount(mat, ai_type)) : (i += 1) {
            var path: c.aiString = undefined;
            if (c.aiGetMaterialTexture(mat, ai_type, i, &path, null, null, null, null, null, null) != 0) return error.TextureLoadError;

            var buffer: [255]u8 = undefined;
            const name = std.fmt.bufPrintZ(&buffer, "{s}{s}", .{ model.directory, path.data[0..path.length] }) catch unreachable;

            for (model.loaded_textures.items) |texture| {
                if (std.mem.eql(u8, name, texture.name)) {
                    try textures.append(texture);
                    break;
                }
            } else {
                const texture = Texture{
                    .texture = textureFromFile(name) catch return error.TextureLoadError,
                    .type = texture_type,
                    .name = try model.arena_allocator.allocator().dupe(u8, name),
                };
                try model.loaded_textures.append(texture);
                try textures.append(texture);
            }
        }
    }

    fn textureFromFile(file: [:0]const u8) !gl.Texture {
        const image = try Image.load(file, .{ .flip = true });
        defer image.unload();

        const format: gl.PixelFormat = switch (image.channels) {
            1 => .red,
            3 => .rgb,
            4 => .rgba,
            else => return error.ImageFormatError,
        };

        const texture = gl.genTexture();

        gl.bindTexture(.@"2d", texture);
        gl.texImage2D(.@"2d", 0, format, image.width, image.height, format, .unsigned_byte, image.data);
        gl.generateMipmap(.@"2d");

        gl.texParameter(.@"2d", .wrap_s, .repeat);
        gl.texParameter(.@"2d", .wrap_t, .repeat);
        gl.texParameter(.@"2d", .min_filter, .linear_mipmap_linear);
        gl.texParameter(.@"2d", .mag_filter, .linear);

        return texture;
    }
};
