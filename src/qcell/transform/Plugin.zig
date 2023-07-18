const ecs = @import("../../ecs.zig");
const ng = @import("../../ng.zig");
const ngm = ng.math;



pub const ncs_components = .{
	.xform_position = ngm.Vec2f,
	.xform_rotation = f32,
	.xform_scale = ngm.Vec2f,
	.xform_origin = ngm.Vec2f,

	.xform = ngm.Mat3,
};



pub fn init(
	world: *ecs.World
) !void {
	try world.addSystem(.mach_update, &updateTransformPRSO);
	try world.addSystem(.mach_update, &updateTransformPRS);
	try world.addSystem(.mach_update, &updateTransformPR);
	try world.addSystem(.mach_update, &updateTransformPO);
	try world.addSystem(.mach_update, &updateTransformP);
}



const Query = ecs.Query;
const Mut = ecs.Mut;
const Without = ecs.Without;

fn updateTransformPRSO(
	q: Query(.{ 
		.xform_position, .xform_rotation, .xform_scale, .xform_origin,
		Mut(.xform)
	})
) !void {
	var iter = q.iter();
	while( iter.next() ) |entry| {
		const position: ngm.Vec2f = entry.get(.xform_position);
		const rotation: f32 = entry.get(.xform_rotation);
		const scale: ngm.Vec2f = entry.get(.xform_scale);
		const origin: ngm.Vec2f = entry.get(.xform_origin);
		var transform: *ngm.Mat3 = entry.getPtr(.xform);

		transform.* = ngm.Mat3.initPositionRotationScaleOrigin(
			position, rotation, scale, origin
		);
	}
}

fn updateTransformPRS(
	q: Query(.{ 
		.xform_position, .xform_rotation, .xform_scale,
		Mut(.xform),
		Without(.xform_origin)
	})
) !void {
	var iter = q.iter();
	while( iter.next() ) |entry| {
		const position: ngm.Vec2f = entry.get(.xform_position);
		const rotation: f32 = entry.get(.xform_rotation);
		const scale: ngm.Vec2f = entry.get(.xform_scale);
		const origin = ngm.Vec2f.zero;
		var transform: *ngm.Mat3 = entry.getPtr(.xform);

		transform.* = ngm.Mat3.initPositionRotationScaleOrigin(
			position, rotation, scale, origin
		);
	}
}

fn updateTransformPR(
	q: Query(.{ 
		.xform_position, .xform_rotation,
		Mut(.xform),
		Without(.xform_origin), Without(.xform_scale),
	})
) !void {
	var iter = q.iter();
	while( iter.next() ) |entry| {
		const position: ngm.Vec2f = entry.get(.xform_position);
		const rotation: f32 = entry.get(.xform_rotation);
		const scale = ngm.Vec2f.one;
		const origin = ngm.Vec2f.zero;
		var transform: *ngm.Mat3 = entry.getPtr(.xform);

		transform.* = ngm.Mat3.initPositionRotationScaleOrigin(
			position, rotation, scale, origin
		);
	}
}

fn updateTransformP(
	q: Query(.{ 
		.xform_position,
		Mut(.xform),
		Without(.xform_origin), Without(.xform_scale), Without(.xform_rotation)
	})
) !void {
	var iter = q.iter();
	while( iter.next() ) |entry| {
		const position: ngm.Vec2f = entry.get(.xform_position);
		const rotation: f32 = 0;
		const scale = ngm.Vec2f.one;
		const origin = ngm.Vec2f.zero;
		var transform: *ngm.Mat3 = entry.getPtr(.xform);

		transform.* = ngm.Mat3.initPositionRotationScaleOrigin(
			position, rotation, scale, origin
		);
	}
}

fn updateTransformPO(
	q: Query(.{ 
		.xform_position, .xform_origin,
		Mut(.xform),
		Without(.xform_scale), Without(.xform_rotation)
	})
) !void {
	var iter = q.iter();
	while( iter.next() ) |entry| {
		const position: ngm.Vec2f = entry.get(.xform_position);
		const rotation: f32 = 0;
		const scale = ngm.Vec2f.one;
		const origin: ngm.Vec2f = entry.get(.xform_origin);
		var transform: *ngm.Mat3 = entry.getPtr(.xform);

		transform.* = ngm.Mat3.initPositionRotationScaleOrigin(
			position, rotation, scale, origin
		);
	}
}
