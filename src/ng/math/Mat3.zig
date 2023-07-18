const std = @import("std");
const Vec2f = @import("vec2.zig").Vec2(f32);
const Vec3f = @import("vec3.zig").Vec3(f32);
const Mat4 = @import("Mat4.zig");

const Vector = Vec3f.Vector;
const Self = @This();



pub const identity = Self {};



columns: [3]Vec3f = .{
    Vec3f.init(1, 0, 0),
    Vec3f.init(0, 1, 0),
    Vec3f.init(0, 0, 1),
},


pub fn init(
    c0: Vec3f,
    c1: Vec3f,
    c2: Vec3f
) Self {
    return .{ .columns = .{ c0, c1, c2 }};
}

pub fn initElem(
    v11: f32, v12: f32, v13: f32,
    v21: f32, v22: f32, v23: f32,
    v31: f32, v32: f32, v33: f32
) Self {
    return .{ .columns = .{
        Vec3f.init(v11, v21, v31),
        Vec3f.init(v12, v22, v32),
        Vec3f.init(v13, v23, v33)
    }};
}

pub fn initTranslation(
    pos: Vec2f
) Self {
    return initElem(
        1, 0, pos.x(), 
        0, 1, pos.y(),
        0, 0, 1
    );
}

pub fn initScaling(
    scale: Vec2f
) Self {
    return initElem(
        scale.x(), 0, 0,
        0, scale.y(), 0,
        0, 0, 1
    );
}

pub fn initRotation(
    rot: f32
) Self {
    return initElem(
        @cos(rot), -@sin(rot), 0,
        @sin(rot), @cos(rot), 0,
        0, 0, 1
    );
}

pub fn initShear(
    f: Vec2f
) Self {
    return initElem(
        1, f.x(), 0,
        f.y(), 1, 0,
        0, 0, 1
    );
}

pub fn initPositionRotationScaleOrigin(
    pos: Vec2f,
    rot: f32,
    scl: Vec2f,
    ori: Vec2f,
) Self {
    const cos = @cos(rot);
    const sin = @sin(rot);

    const sxc = scl.x() * cos;
    const syc = scl.y() * cos;
    const sxs = scl.x() * sin;
    const sys = scl.y() * sin;
    const tx = -ori.x() * sxc - ori.y() * sys + pos.x();
    const ty =  ori.x() * sxs - ori.y() * syc + pos.y();

    return initElem(
         sxc, sys, tx,
        -sxs, syc, ty,
        0,    0,   1
    );
}

pub fn asArray(
    self: Self
) [9]f32 {
    return [9]f32 {
        self.get(0, 0), self.get(1, 0), self.get(2, 0),
        self.get(0, 1), self.get(1, 1), self.get(2, 1),
        self.get(0, 2), self.get(1, 2), self.get(2, 2)
    };
}



pub fn toMat4(
    self: Self
) Mat4 {
    return Mat4.initElem(
        self.get(0, 0), self.get(1, 0), 0, self.get(2, 0),
        self.get(0, 1), self.get(1, 1), 0, self.get(2, 1),
        0,              0,              1, 0,
        self.get(0, 2), self.get(1, 2), 0, self.get(2, 2)
    );
}



pub fn mul(
    self: Self,
    other: Self,
) Self {
    const xposed = self.transpose();
    
    const c0 = Vec3f.init(
        xposed.columns[0].mul(other.columns[0]).reduce(.Add),
        xposed.columns[1].mul(other.columns[0]).reduce(.Add),
        xposed.columns[2].mul(other.columns[0]).reduce(.Add),
    );
    const c1 = Vec3f.init(
        xposed.columns[0].mul(other.columns[1]).reduce(.Add),
        xposed.columns[1].mul(other.columns[1]).reduce(.Add),
        xposed.columns[2].mul(other.columns[1]).reduce(.Add),
    );
    const c2 = Vec3f.init(
        xposed.columns[0].mul(other.columns[2]).reduce(.Add),
        xposed.columns[1].mul(other.columns[2]).reduce(.Add),
        xposed.columns[2].mul(other.columns[2]).reduce(.Add),
    );

    return init(c0, c1, c2);
}

pub fn mulScalar(
    self: Self,
    other: f32
) Self {
    return init(
        self.columns[0].mul(Vec3f.splat(other)),
        self.columns[1].mul(Vec3f.splat(other)),
        self.columns[2].mul(Vec3f.splat(other)),
    );
}



pub fn transpose(
    self: Self
) Self {
    return init(
        self.getRow(0),
        self.getRow(1),
        self.getRow(2)
    );
}

pub fn adjugate(
    self: Self
) Self {
    const v11 =  self.get(1, 1)*self.get(3, 2) - self.get(1, 2)*self.get(3, 1);
    const v12 = -self.get(1, 0)*self.get(3, 2) + self.get(1, 2)*self.get(3, 0);
    const v13 =  self.get(1, 0)*self.get(3, 1) - self.get(1, 1)*self.get(3, 0);
    const v21 = -self.get(0, 1)*self.get(3, 2) + self.get(0, 2)*self.get(3, 1);
    const v22 =  self.get(0, 0)*self.get(3, 2) - self.get(0, 2)*self.get(3, 0);
    const v23 = -self.get(0, 0)*self.get(3, 1) + self.get(0, 1)*self.get(3, 0);
    const v31 =  self.get(0, 1)*self.get(1, 2) - self.get(0, 2)*self.get(1, 1);
    const v32 = -self.get(0, 0)*self.get(1, 2) + self.get(0, 2)*self.get(1, 0);
    const v33 =  self.get(0, 0)*self.get(1, 1) - self.get(0, 1)*self.get(1, 0);

    return initElem(
        v11, v12, v13, 
        v21, v22, v23, 
        v31, v32, v33
    );
}

pub fn inverse(
    self: Self
) Self {
    return self.adjugate().mulScalar(1.0 / self.determinant());
}

pub fn determinant(
    self: Self
) f32 {
    return self.columns[0].dot(self.columns[1].mul(self.columns[2]));
}



pub inline fn get(
    self: Self,
    col: usize,
    row: usize 
) f32 {
    return self.columns[col].v[row];
}

pub inline fn getRow(
    self: Self,
    idx: usize
) Vec3f {
    return Vec3f.init(
        self.columns[0].v[idx],
        self.columns[1].v[idx],
        self.columns[2].v[idx],
    );
}
