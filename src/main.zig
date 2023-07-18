const std = @import("std");
const mach = @import("mach");
const ecs = @import("ecs.zig");
const ngm = @import("ng.zig").math;
const gpu = mach.gpu;



pub const App = @This();



var gpa = std.heap.GeneralPurposeAllocator(.{}){};

alloc: std.mem.Allocator,
core: mach.Core,
world: ecs.World,

queue: *gpu.Queue,



inline fn uncapturedErrorCb(_: void, typ: gpu.ErrorType, message: [*:0]const u8) void {
    std.log.err("[{s}] {s}", .{
        @tagName(typ),
        message
    });
}


pub fn init(app: *App) !void {
    app.alloc = gpa.allocator();

    try app.core.init(app.alloc, .{
        .title = "qcell v0.1",
    });
    
    app.core.device().setUncapturedErrorCallback({}, uncapturedErrorCb);
    app.queue = app.core.device().getQueue();

    try app.world.init(
        app.alloc,
        128, 128, 16, 8
    );

    app.world.setResource(.mach_app, app);

    try app.world.run(.mach_startup);

    try app.world.addSystem(.mach_update, &testSys);

    const e = try app.world.createEntity();
    try app.world.attachComponent(e, .xform_position, ngm.Vec2f.zero);
    try app.world.attachComponent(e, .xform, ngm.Mat3.identity);
    try app.world.attachComponent(e, .drawable, undefined);
}

pub fn deinit(app: *App) void {
    defer _ = gpa.deinit();
    defer app.core.deinit();
    defer app.world.deinit();
}

pub fn update(app: *App) !bool {
    app.core.device().tick();

    var iter = app.core.pollEvents();
    while( iter.next() ) |event| {
        if( event == .close )
            return true;
    }

    try app.world.run(.mach_update);

    return false;
}



pub fn testSys(
    input_res: ecs.Res(.mach_input),
    q: ecs.Query(.{
        ecs.Mut(.xform_position),
        ecs.With(.drawable)
    }),
) !void {
    var input = input_res.res;

    var iter = q.iter();
    while( iter.next() ) |entry| {
        var pos: *ngm.Vec2f = entry.getPtr(.xform_position);
        var in = ngm.Vec2f.zero;

        if( input.keyPressed(.left) )
            in = in.add(ngm.Vec2f.init( -1,  0 ));
        if( input.keyPressed(.right) )
            in = in.add(ngm.Vec2f.init(  1,  0 ));
        
        if( input.keyPressed(.up) )
            in = in.add(ngm.Vec2f.init(  0, -1 ));
        if( input.keyPressed(.down) )
            in = in.add(ngm.Vec2f.init(  0,  1 ));
        
        pos.* = pos.add(in.mul(ngm.Vec2f.splat(16)));
    }
}