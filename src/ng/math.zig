const vec2 = @import("math/vec2.zig");
const vec3 = @import("math/vec3.zig");
const vec4 = @import("math/vec4.zig");

pub const Mat3 = @import("math/Mat3.zig");
pub const Mat4 = @import("math/Mat4.zig");

pub const Vec2 = vec2.Vec2;
pub const Vec2f = Vec2(f32);
pub const Vec2i = Vec2(i32);
pub const Size2 = Vec2(u32);

pub const Vec3 = vec3.Vec3;
pub const Vec3f = Vec3(f32);
pub const Vec3i = Vec3(i32);
pub const Size3 = Vec3(u32);

pub const Vec4 = vec4.Vec4;
pub const Vec4f = Vec4(f32);
pub const Vec4i = Vec4(i32);

pub const Color = Vec4f;
