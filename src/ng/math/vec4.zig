const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;
const Vec3 = @import("vec3.zig").Vec3;



pub fn Vec4(
    comptime T: type
) type {
    return struct {
        const Self = @This();

        pub const Vector = @Vector(4, T);
        pub const Component = Vec4Component;

        pub const zero = init(0, 0, 0, 0);
        pub const one = init(1, 1, 1, 1);
        
        pub const black = init(0, 0, 0, 1);
        pub const white = init(1, 1, 1, 1);
        pub const red = init(1, 0, 0, 1);
        pub const blue = init(0, 1, 0, 1);
        pub const green = init(0, 0, 1, 1);



        v: Vector = .{0, 0, 0, 0},



        pub inline fn from(
            v: Vector,
        ) Self {
            return .{ .v = v };
        }

        pub inline fn splat(
            v: T
        ) Self {
            return from(@splat(4, v));
        }

        pub inline fn init(
            x_: T,
            y_: T,
            z_: T,
            w_: T
        ) Self {
            return from(.{x_, y_, z_, w_});
        }



        pub fn asArray(
            self: Self
        ) [4]T {
            return .{ self.v[0], self.v[1], self.v[2], self.v[3] };
        }



        pub inline fn x(
            self: Self
        ) T {
            return self.v[0];
        }

        pub inline fn y(
            self: Self
        ) T {
            return self.v[1];
        }

        pub inline fn z(
            self: Self
        ) T {
            return self.v[2];
        }

        pub inline fn w(
            self: Self
        ) T {
            return self.v[3];
        }

        pub const r = x;
        pub const g = y;
        pub const b = z;
        pub const a = w;
    };
}



pub const Vec4Component = enum {
    x, y, z, w
};
