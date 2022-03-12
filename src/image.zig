const c = @cImport({
    @cInclude("stb_image.h");
});

pub const Image = struct {
    width: usize,
    height: usize,
    data: [*]u8 = undefined,

    pub fn load(contents: []const u8) !Image {
        var width: c_int = undefined;
        var height: c_int = undefined;
        var n_channels: c_int = undefined;

        const data = c.stbi_load_from_memory(contents.ptr, @intCast(c_int, contents.len), &width, &height, &n_channels, 0) orelse return error.ImageLoadError;

        return Image{
            .data = data,
            .width = @intCast(usize, width),
            .height = @intCast(usize, height),
        };
    }

    pub fn unload(self: Image) void {
        _ = c.stbi_image_free(self.data);
    }
};
