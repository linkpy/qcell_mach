const std = @import("std");



pub fn Vec2(
    comptime T: type
) type {
    return struct {
        const Self = @This();

        pub const Vector = @Vector(2, T);
        pub const Component = Vec2Component;

        pub const zero = init(0, 0);
        pub const one = init(1, 1);
        pub const right = init(1, 0);
        pub const down = init(0, 1);
        pub const left = init(-1, 0);
        pub const up = init(0, -1);



        v: Vector = .{ 0, 0 },



        pub inline fn from(
            v: Vector
        ) Self {
            return .{ .v = v };
        }

        pub inline fn splat(
            v: T
        ) Self {
            return from(@splat(2, v));
        }

        pub inline fn init(
            x_: T,
            y_: T
        ) Self {
            return from(.{ x_, y_ });
        }



        pub inline fn neg(
            self: Self
        ) Self {
            return splat(0).sub(self);
        }

        pub inline fn add(
            self: Self,
            other: Self
        ) Self {
            return from(self.v + other.v);
        }

        pub inline fn sub(
            self: Self,
            other: Self
        ) Self {
            return from(self.v - other.v);
        }

        pub inline fn mul(
            self: Self,
            other: Self
        ) Self {
            return from(self.v * other.v);
        }

        pub inline fn div(
            self: Self,
            other: Self
        ) Self {
            return from(self.v / other.v);
        }

        pub inline fn swizzle2(
            self: Self,
            comptime x_: Component,
            comptime y_: Component,
        ) Self {
            return from(@shuffle(T, self.v, undefined, .{
                @intFromEnum(x_),
                @intFromEnum(y_),
            }));
        }

        pub inline fn reduce(
            self: Self,
            comptime op: std.builtin.ReduceOp
        ) T {
            return @reduce(op, self.v);
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

        pub inline fn xx(
            self: Self
        ) Self {
            return self.swizzle2(.x, .x);
        }

        pub inline fn xy(
            self: Self
        ) Self {
            return self.swizzle2(.x, .y);
        }

        pub inline fn yx(
            self: Self
        ) Self {
            return self.swizzle2(.y, .x);
        }

        pub inline fn yy(
            self: Self
        ) Self {
            return self.swizzle2(.y, .y);
        }
    };
}

pub const Vec2Component = enum(u8) {
    x, y
};
