

const Vector = @Vector(4, f32);
const Self = @This();



columns: [4]Vector = .{
    .{ 1, 0, 0, 0 },
    .{ 0, 1, 0, 0 },
    .{ 0, 0, 1, 0 },
    .{ 0, 0, 0, 1 },
},



pub fn initElem(
    v11: f32, v12: f32, v13: f32, v14: f32,
    v21: f32, v22: f32, v23: f32, v24: f32,
    v31: f32, v32: f32, v33: f32, v34: f32,
    v41: f32, v42: f32, v43: f32, v44: f32
) Self {
    return .{ .columns = .{
       .{ v11, v21, v31, v41 },
       .{ v12, v22, v32, v42 },
       .{ v13, v23, v33, v43 },
       .{ v14, v24, v34, v44 },
    }};
}

pub fn initOrtho(
    left: f32, right: f32,
    bottom: f32, top: f32,
    near: f32, far: f32
) Self {
    return initElem(
        2 / (right - left), 0, 0, -(right+left)/(right-left),
        0, 2 / (top - bottom), 0, -(top+bottom)/(top-bottom),
        0, 0, -2 / (far - near), -(far+near)/(far-near),
        0, 0, 0, 1
    );
}



pub fn asArray(
    self: Self
) [16]f32 {
    return @bitCast(self.columns);
}
