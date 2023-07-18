const std = @import("std");
const EcsWorld = @import("src/ncs/world.zig").World;



const TestPlugin = struct {
	pub const ncs_components = .{
		.test_comp = TestComp,
	};
	pub const ncs_resources = .{
		.test_res = TestRes,
	};
	pub const ncs_stages = .{
		.test_stage,
	};


	pub const TestRes = struct {
		text: []const u8,
	};

	pub const TestComp = struct {
		text: []const u8,
	};


	pub fn init(world: *World) !void {
		std.debug.print("TestPlugin.init\n", .{});
		
		world.setResource(.test_res, TestRes { .text = "resource" });
		try world.addSystem(.test_stage, &testSystem);
		try world.addSystemBefore(.test_stage, &otherSystem, &testSystem);
	}

	pub fn deinit(_: *World) void {
		std.debug.print("TestPlugin.deinit\n", .{});
	}



	pub fn testSystem(
		res: World.Res(.test_res),
		q: World.Query(.{ .test_comp }),
	) !void {
		std.debug.print("testSystem: res = {s}\n", .{ res.res.text });

		var iter = q.iter();
		while( iter.next() ) |entry| {
			const ent = @intFromEnum(entry.entity);
			const comp = entry.get(.test_comp);
			std.debug.print("testSystem: entity #{} = {s}\n", .{ ent, comp.text });
		}
	}

	pub fn otherSystem(
		cmds: *World.CommandBuffer,
	) !void {
		std.debug.print("otherSystem: called\n", .{});

		var ent = try cmds.createEntity();
		try ent.attachComponent(.test_comp, .{ .text = "From command buffer."});
	}
};



const desc = .{
	.plugins = .{
		TestPlugin,
	},
};

const World = EcsWorld(desc);



pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
	defer _ = gpa.deinit();

	const alloc = gpa.allocator();

	var world: World = undefined;
	try world.init(alloc, 16, 16, 16, 16);
	defer world.deinit();

	const e0 = try world.createEntity();
	try world.attachComponent(e0, .test_comp, .{ .text = "Entity 0" });

	const e1 = try world.createEntity();
	try world.attachComponent(e1, .test_comp, .{ .text = "Entity 1" });

	try world.run(.test_stage);
}
