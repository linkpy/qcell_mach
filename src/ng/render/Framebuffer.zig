const std = @import("std");
const mach = @import("mach");
const ng = @import("../../ng.zig");

const gpu = mach.gpu;
const ngm = ng.math;

const Framebuffer = @This();



label: ?[*:0]const u8 = null,
texture: *gpu.Texture = undefined,
texture_view: *gpu.TextureView = undefined,

clear_content: bool = true,
clear_color: ngm.Color = ngm.Color.black,

size: ngm.Size2 = ngm.Size2.zero,
format: gpu.Texture.Format = .rgba8_unorm,



pub fn create(
	self: *Framebuffer,
	device: *gpu.Device
) void {
	self.texture = device.createTexture(&.{
		.label = self.label,
		.size = .{
			.width = self.size.x(),
			.height = self.size.y()
		},
		.format = self.format,
		.usage = .{ .texture_binding = true, .render_attachment = true }
	});

	self.view = self.texture.createView(&.{
		.label = self.label,
	});

}

pub fn deinit(
	self: *Framebuffer,
) void {
	self.texture.release();
	self.texture_view.release();
}



pub fn getColorAttachment(
	self: *Framebuffer
) gpu.RenderPassColorAttachment {
	return .{
		.view = self.texture_view,
		.clear_color = .{
			.r = self.clear_color.r(),
			.g = self.clear_color.g(),
			.b = self.clear_color.b(),
			.a = self.clear_color.a(),
		},
		.load_op = if( self.clear_content ) .clear else .load,
		.store_op = .store,
	};
}
