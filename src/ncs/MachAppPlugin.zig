const ecs = @import("../ecs.zig");
const App = @import("../main.zig").App;
const Core = @import("mach").Core;



pub const ncs_resources = .{
	.mach_app = *App,
	.mach_input = InputState,
};

pub const ncs_stages = .{
	.mach_startup,
	.mach_update,
};



pub const InputState = struct {
	core: *Core,



	pub fn keyPressed(
		self: InputState,
		key: Core.Key
	) bool {
		return self.core.keyPressed(key);
	}

	pub fn keyReleased(
		self: InputState,
		key: Core.Key
	) bool {
		return self.core.keyReleased(key);
	}
};



pub fn init(
	world: *ecs.World
) !void {
	try world.addSystem(.mach_startup, &initSys);
}



fn initSys(
	app_res: ecs.Res(.mach_app),
	input_res: ecs.ResMut(.mach_input),
) !void {
	var app: *App = app_res.res;

	input_res.res.* = .{ .core = &app.core };
}
