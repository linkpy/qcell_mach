const std = @import("std");
const mach = @import("mach");
const ecs = @import("ecs.zig");
const ngm = @import("ng.zig").math;
const gpu = mach.gpu;
const Core = mach.Core;



pub const ncs_components = .{
	.drawable = Drawable,
	.drawable_initialized = void,
};

pub const ncs_resources = .{
	.pipeline = Pipeline,
	.projection = ngm.Mat4,
};



pub const Pipeline = struct {
	buffer: *gpu.Buffer,
	pipeline: *gpu.RenderPipeline,
	bind_group_layout: *gpu.BindGroupLayout,
};

pub const Drawable = struct {
	buffer: *gpu.Buffer,
	bind_group: *gpu.BindGroup,
};



pub fn init(
	world: *ecs.World
) !void {
	try world.addSystem(.mach_startup, &startupSys);
	try world.addSystem(.mach_update, &initDrawableSys);
	try world.addSystem(.mach_update, &updateDrawableSys);
	try world.addSystem(.mach_update, &updateProjectionSys);
	try world.addSystem(.mach_update, &renderDrawableSys);
}



fn startupSys(
	app_res: ecs.Res(.mach_app),
	pipeline_res: ecs.ResMut(.pipeline),
	projection_res: ecs.ResMut(.projection),
) !void {
	var core: *Core = &app_res.res.core;
	var pipeline_info: *Pipeline = pipeline_res.res;
	var projection: *ngm.Mat4 = projection_res.res;


	projection.* = ngm.Mat4.initOrtho(-480, 480, 270, -270, 10, -10);


	const module = core.device().createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));
	defer module.release();

	const bgl = core.device().createBindGroupLayout(
		&gpu.BindGroupLayout.Descriptor.init(.{
			.entries = &.{
				gpu.BindGroupLayout.Entry.buffer(
					0, .{ .vertex = true }, .uniform, false, 0
				),
				gpu.BindGroupLayout.Entry.buffer(
					1, .{ .vertex = true }, .uniform, false, 0
				),
			}
		})
	);

	const pl = core.device().createPipelineLayout(
		&gpu.PipelineLayout.Descriptor.init(.{
			.bind_group_layouts = &.{bgl}
		})
	);
	defer pl.release();

	const pipeline = core.device().createRenderPipeline(&.{
		.fragment = &gpu.FragmentState.init(.{
			.module = module,
			.entry_point = "fragment_main",
			.targets = &.{ .{ 
				.format = core.descriptor().format,
				.blend = &.{},
				.write_mask = gpu.ColorWriteMaskFlags.all,
			}},
		}),
		.layout = pl,
		.vertex = gpu.VertexState.init(.{
			.module = module,
			.entry_point = "vertex_main",
			.buffers = &.{},
		}),
	});

	const buffer = core.device().createBuffer(&.{
		.usage = .{ .copy_dst = true, .uniform = true },
		.size = @sizeOf(ngm.Mat4),
	});

	pipeline_info.* = .{
		.buffer = buffer,
		.pipeline = pipeline,
		.bind_group_layout = bgl,
	};
}

fn initDrawableSys(
	app_res: ecs.Res(.mach_app),
	pipeline_res: ecs.Res(.pipeline),
	cmds: *ecs.CommandBuffer,
	q: ecs.Query(.{
		ecs.Mut(.drawable),
		ecs.Without(.drawable_initialized),
	}),
) !void {
	var core: *Core = &app_res.res.core;
	var pipeline_info: Pipeline = pipeline_res.res;

	var iter = q.iter();
	while( iter.next() ) |entry| {
		var drawable: *Drawable = entry.getPtr(.drawable);

		const buffer = core.device().createBuffer(&.{
			.usage = .{ .copy_dst = true, .uniform = true },
			.size = @sizeOf(ngm.Mat4),
		});

		const bg = core.device().createBindGroup(
			&gpu.BindGroup.Descriptor.init(.{
				.layout = pipeline_info.bind_group_layout,
				.entries = &.{
					gpu.BindGroup.Entry.buffer(0, pipeline_info.buffer, 0, @sizeOf(ngm.Mat4)),
					gpu.BindGroup.Entry.buffer(1, buffer, 0, @sizeOf(ngm.Mat4)),
				}
			})
		);

		drawable.* = .{
			.buffer = buffer,
			.bind_group = bg
		};

		try cmds.attachComponent(entry.entity, .drawable_initialized, {});
	}
}

fn updateDrawableSys(
	app_res: ecs.Res(.mach_app),
	q: ecs.Query(.{
		.drawable, .xform,
		ecs.With(.drawable_initialized),
	})
) !void {
	var core: *Core = &app_res.res.core;

	var iter = q.iter();
	while( iter.next() ) |entry| {
		const drawable: Drawable = entry.get(.drawable);
		const xform: ngm.Mat3 = entry.get(.xform);

		const data = xform.toMat4().asArray();
		core.device().getQueue().writeBuffer(drawable.buffer, 0, &data);
	}
}

fn updateProjectionSys(
	app_res: ecs.Res(.mach_app),
	pipeline_res: ecs.Res(.pipeline),
	projection_res: ecs.Res(.projection),
) !void {
	var core: *Core = &app_res.res.core;
	const pipeline: Pipeline = pipeline_res.res;
	const projection: ngm.Mat4 = projection_res.res;

	core.device().getQueue().writeBuffer(pipeline.buffer, 0, &projection.asArray());
}

fn renderDrawableSys(
	app_res: ecs.Res(.mach_app),
	pipeline_res: ecs.Res(.pipeline),
	q: ecs.Query(.{
		.drawable,
		ecs.With(.drawable_initialized),
	})
) !void {
	var core: *Core = &app_res.res.core;
	const pipeline: Pipeline = pipeline_res.res;

	const back_buffer_view = core.swapChain().getCurrentTextureView().?;
	const color_attachment = gpu.RenderPassColorAttachment {
		.view = back_buffer_view,
		.clear_value = std.mem.zeroes(gpu.Color),
		.load_op = .clear,
		.store_op = .store,
	};

	const encoder = core.device().createCommandEncoder(null);
	const render_pass_info = gpu.RenderPassDescriptor.init(.{
		.color_attachments = &.{color_attachment}
	});

	const pass = encoder.beginRenderPass(&render_pass_info);
	pass.setPipeline(pipeline.pipeline);

	var iter = q.iter();
	while( iter.next() ) |entry| {
		const drawable: Drawable = entry.get(.drawable);

		pass.setBindGroup(0, drawable.bind_group, null);
		pass.draw(6, 1, 0, 0);
	}

	pass.end();
	pass.release();

	var command = encoder.finish(null);
	encoder.release();

	core.device().getQueue().submit(&.{command});
	command.release();
	core.swapChain().present();
	back_buffer_view.release();
}