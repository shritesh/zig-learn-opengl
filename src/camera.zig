const std = @import("std");
const math = @import("zmath");
const tau = std.math.tau;

pub const CameraMovement = enum {
    forward,
    backward,
    left,
    right,
};

pub const Camera = struct {
    position: math.Vec,
    world_up: math.Vec,
    yaw: f32 = -90.0,
    pitch: f32 = 0.0,

    movement_speed: f32 = 2.5,
    mouse_sensitivity: f32 = 0.1,
    zoom: f32 = 45.0,

    pub fn init(position: math.Vec, world_up: math.Vec) Camera {
        return Camera{
            .position = position,
            .world_up = world_up,
        };
    }

    pub inline fn direction(camera: Camera) math.Vec {
        return math.f32x4(
            math.cos(camera.yaw * tau / 360.0) * math.cos(camera.pitch * tau / 360.0),
            math.sin(camera.pitch * tau / 360.0),
            math.sin(camera.yaw * tau / 360.0) * math.cos(camera.pitch * tau / 360.0),
            1.0,
        );
    }

    pub inline fn front(camera: Camera) math.Vec {
        return math.normalize3(camera.direction());
    }

    pub inline fn right(camera: Camera) math.Vec {
        return math.normalize3(math.cross3(camera.front(), camera.world_up));
    }

    pub inline fn up(camera: Camera) math.Vec {
        return math.normalize3(math.cross3(camera.right(), camera.front()));
    }

    pub fn viewMatrix(camera: Camera) math.Mat {
        return math.lookAtRh(
            camera.position,
            camera.position + camera.front(),
            camera.up(),
        );
    }

    pub fn processKeyboard(camera: *Camera, movement: CameraMovement, delta_time: f32) void {
        const velocity = math.f32x4s(camera.movement_speed * delta_time);
        switch (movement) {
            .forward => camera.position += camera.front() * velocity,
            .backward => camera.position -= camera.front() * velocity,
            .left => camera.position -= camera.right() * velocity,
            .right => camera.position += camera.right() * velocity,
        }
    }

    pub fn processMouseMovement(camera: *Camera, x_offset: f32, y_offset: f32, flags: struct { constrain_pitch: bool = true }) void {
        camera.yaw += x_offset * camera.mouse_sensitivity;
        camera.pitch += y_offset * camera.mouse_sensitivity;

        if (flags.constrain_pitch) {
            if (camera.pitch > 89.0) camera.pitch = 89.0;
            if (camera.pitch < -89.0) camera.pitch = -89.0;
        }
    }

    pub fn processMouseScroll(camera: *Camera, y_offset: f32) void {
        camera.zoom -= y_offset;

        if (camera.zoom < 1.0) camera.zoom = 1.0;
        if (camera.zoom > 45.0) camera.zoom = 45.0;
    }
};
