const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;



pub fn Vec3(
    comptime T: type
) type {
    return struct {
        const Self = @This();
        const Vec2T = Vec2(T);

        pub const is_vector = true;
        pub const Vector = @Vector(3, T);

        pub const Component = Vec3Component;

        pub const zero = init(0, 0, 0);
        pub const one = init(1, 1, 0);
        pub const right = init(1, 0, 0);
        pub const down = init(0, 1, 0);
        pub const left = init(-1, 0, 0);
        pub const up = init(0, -1, 0);
        pub const forward = init(0, 0, -1);
        pub const backward = init(0, 0, 1);



        v: Vector = .{ 0, 0, 0 },



        pub inline fn from(
            v: Vector
        ) Self {
            return .{ .v = v };
        }

        pub inline fn splat(
            v: T
        ) Self {
            return init(@splat(3, v));
        }

        pub inline fn init(
            x_: T,
            y_: T,
            z_: T,
        ) Self {
            return from(.{ x_, y_, z_ });
        }



        pub inline fn asArray(
            self: Self
        ) [3]T {
            return .{ self.v[0], self.v[1], self.v[2] };
        }



        pub inline fn lengthSquared(
            self: Self
        ) T {
            return self.dot(self);
        }

        pub inline fn length(
            self: Self
        ) T {
            return @sqrt(self.lengthSquared());
        }

        pub inline fn normalize(
            self: Self
        ) Self {
            const len = splat(self.length());
            return self.mul(one.div(len));
        }



        pub inline fn dot(
            self: Self,
            other: Self
        ) T {
            return self.mul(other).reduce(.Add);
        }

        pub inline fn cross(
            self: Self,
            other: Self
        ) Self {
            const a = self.yzx().mul(other.zxy());
            const b = self.zxy().mul(other.yzx());
            return a.sub(b);
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
        ) Vec2T {
            return Vec2T.from(@shuffle(T, self.v, undefined, .{
                @intFromEnum(x_),
                @intFromEnum(y_),
            }));
        }

        pub inline fn swizzle3(
            self: Self,
            comptime x_: Component,
            comptime y_: Component,
            comptime z_: Component
        ) Self {
            return from(@shuffle(T, self.v, undefined, .{
                @intFromEnum(x_),
                @intFromEnum(y_),
                @intFromEnum(z_),
            }));
        }

        pub inline fn reduce(
            self: Self,
            comptime op: std.builtin.ReduceOp
        ) T {
            return @reduce(op, self.v);
        }



        pub inline fn x(self: Self) T {
            return self.v[0];
        }

        pub inline fn y(self: Self) T {
            return self.v[1];
        }

        pub inline fn z(self: Self) T {
            return self.v[2];
        }

        pub inline fn xx(self: Self) Vec2T {
            return self.swizzle2(.x, .x);
        }

        pub inline fn xy(self: Self) Vec2T {
            return self.swizzle2(.x, .y);
        }

        pub inline fn xz(self: Self) Vec2T {
            return self.swizzle2(.x, .z);
        }

        pub inline fn yx(self: Self) Vec2T {
            return self.swizzle2(.y, .x);
        }

        pub inline fn yy(self: Self) Vec2T {
            return self.swizzle2(.y, .y);
        }

        pub inline fn yz(self: Self) Vec2T {
            return self.swizzle2(.y, .z);
        }

        pub inline fn zx(self: Self) Vec2T {
            return self.swizzle2(.z, .x);
        }

        pub inline fn zy(self: Self) Vec2T {
            return self.swizzle2(.z, .y);
        }

        pub inline fn zz(self: Self) Vec2T {
            return self.swizzle2(.z, .z);
        }

        pub inline fn xxx(self: Self) Self {
            return self.swizzle3(.x, .x, .x);
        }

        pub inline fn xxy(self: Self) Self {
            return self.swizzle3(.x, .x, .y);
        }

        pub inline fn xxz(self: Self) Self {
            return self.swizzle3(.x, .x, .z);
        }

        pub inline fn xyx(self: Self) Self {
            return self.swizzle3(.x, .y, .x);
        }

        pub inline fn xyy(self: Self) Self {
            return self.swizzle3(.x, .y, .y);
        }

        pub inline fn xyz(self: Self) Self {
            return self.swizzle3(.x, .y, .z);
        }

        pub inline fn xzx(self: Self) Self {
            return self.swizzle3(.x, .z, .x);
        }

        pub inline fn xzy(self: Self) Self {
            return self.swizzle3(.x, .z, .y);
        }

        pub inline fn xzz(self: Self) Self {
            return self.swizzle3(.y, .z, .z);
        }

        pub inline fn yxx(self: Self) Self {
            return self.swizzle3(.y, .x, .x);
        }

        pub inline fn yxy(self: Self) Self {
            return self.swizzle3(.y, .x, .y);
        }

        pub inline fn yxz(self: Self) Self {
            return self.swizzle3(.y, .x, .z);
        }

        pub inline fn yyx(self: Self) Self {
            return self.swizzle3(.y, .y, .x);
        }

        pub inline fn yyy(self: Self) Self {
            return self.swizzle3(.y, .y, .y);
        }

        pub inline fn yyz(self: Self) Self {
            return self.swizzle3(.y, .y, .z);
        }

        pub inline fn yzx(self: Self) Self {
            return self.swizzle3(.y, .z, .x);
        }

        pub inline fn yzy(self: Self) Self {
            return self.swizzle3(.y, .z, .y);
        }

        pub inline fn yzz(self: Self) Self {
            return self.swizzle3(.y, .z, .z);
        }

        pub inline fn zxx(self: Self) Self {
            return self.swizzle3(.z, .x, .x);
        }

        pub inline fn zxy(self: Self) Self {
            return self.swizzle3(.z, .x, .y);
        }

        pub inline fn zxz(self: Self) Self {
            return self.swizzle3(.z, .x, .z);
        }

        pub inline fn zyx(self: Self) Self {
            return self.swizzle3(.z, .y, .x);
        }

        pub inline fn zyy(self: Self) Self {
            return self.swizzle3(.z, .y, .y);
        }

        pub inline fn zyz(self: Self) Self {
            return self.swizzle3(.z, .y, .z);
        }

        pub inline fn zzx(self: Self) Self {
            return self.swizzle3(.z, .z, .x);
        }

        pub inline fn zzy(self: Self) Self {
            return self.swizzle3(.z, .z, .y);
        }

        pub inline fn zzz(self: Self) Self {
            return self.swizzle3(.z, .z, .z);
        }
    };
}


pub const Vec3Component = enum(u8) {
    x, y, z
};
