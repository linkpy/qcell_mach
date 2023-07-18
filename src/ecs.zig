const ncs = @import("ncs/world.zig");

const MachAppPlugin = @import("ncs/MachAppPlugin.zig");
const TransformPlugin = @import("qcell/transform/Plugin.zig");



const desc = .{
	.plugins = .{
		MachAppPlugin,
		TransformPlugin,
		@import("TestPlugin.zig"),
	},
};

pub const World = ncs.World(desc);



pub const EntityIndex = World.EntityIndex;
pub const ComponentIndex = World.ComponentIndex;
pub const CommandBuffer = World.CommandBuffer;
pub const Mut = World.Mut;
pub const With = World.With;
pub const Without = World.Without;
pub const Res = World.Res;
pub const ResMut = World.ResMut;
pub const Query = World.Query;
