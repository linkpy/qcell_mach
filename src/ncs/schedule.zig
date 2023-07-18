const std = @import("std");
const meta = @import("meta.zig");
const sys = @import("system");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;


// Enums


pub fn StageEnum(
	comptime stages: []const []const u8,
) type {
	return @Type(meta.enumFromNames(stages, u32));
}


// Storages


pub fn ScheduleStorage(
	comptime SystemImpl: type,
	comptime stage_names: []const []const u8,
) type {
	const System = SystemImpl.System;

	var builder = meta.StructBuilder {};

	for( stage_names ) |name| {
		builder.addField(name, ArrayList(System));
	}

	return @Type(builder.finish(false));
}

// Stores

pub fn ScheduleStore(
	comptime SystemImpl: type,
	comptime stage_names: []const []const u8,
) type {
	return struct {
		pub const StageName = StageEnum(stage_names);
		const Storage = ScheduleStorage(SystemImpl, stage_names);
		const System = SystemImpl.System;
		const Components = SystemImpl.Components;
		const Resources = SystemImpl.Resources;
		const Entities = SystemImpl.Entities;
		const CommandBuffer = SystemImpl.CommandBuffer;
		const Self = @This();

		storage: Storage = undefined,

		// init/deinit

		pub fn init(
			self: *Self,
			alloc: Allocator,
			cap: usize
		) Allocator.Error!void {
			inline for( stage_names ) |name| {
				@field(self.storage, name) = try ArrayList(System).initCapacity(alloc, cap);
			}
		}

		pub fn deinit(
			self: *Self,
			alloc: Allocator,
		) void {
			inline for( stage_names ) |name| {
				@field(self.storage, name).deinit(alloc);
			}
		}

		// system arrays

		pub fn getSystems(
			self: Self,
			comptime name: StageName
		) []const System {
			return @field(self.storage, @tagName(name)).items;
		}

		// execution

		pub fn run(
			self: Self,
			comptime name: StageName,
			components: *Components,
			resources: *Resources,
			entities: *Entities,
			cmdbuf: *CommandBuffer,
		) anyerror!void {
			for( self.getSystems(name) ) |system| {
				try system.run(components, resources, entities, cmdbuf);
				
				try cmdbuf.execute(components, entities);
				cmdbuf.reset();
			}
		}

		// insertion

		pub fn insertAfterAll(
			self: *Self,
			alloc: Allocator,
			comptime name: StageName,
			system: System,
		) Allocator.Error!void {
			try @field(self.storage, @tagName(name)).append(alloc, system);
		}

		pub fn insertBeforeAll(
			self: *Self,
			alloc: Allocator,
			comptime name: StageName,
			system: System,
		) Allocator.Error!void {
			try @field(self.storage, @tagName(name)).insert(alloc, 0, system);
		}

		pub fn insertAfter(
			self: *Self,
			alloc: Allocator,
			comptime name: StageName,
			system: System,
			after: usize, // System.function field 
		) Allocator.Error!void {
			const systems = self.getSystems(name);
			var idx: usize = 0;
			while( idx < systems.len ) : ( idx += 1 ) {
				if( systems[idx].function == after )
					break;
			}

			try @field(self.storage, @tagName(name)).insert(alloc, idx+1, system);
		}

		pub fn insertBefore(
			self: *Self,
			alloc: Allocator,
			comptime name: StageName,
			system: System,
			before: usize, // System.function field
		) Allocator.Error!void {
			const systems = self.getSystems(name);
			var idx: usize = 0;
			while( idx < systems.len ) : ( idx += 1 ) {
				if( systems[idx].function == before )
					break;
			}

			// if the `before` system wasnt found
			if( idx == systems.len ) 
				idx = 0; 

			try @field(self.storage, @tagName(name)).insert(alloc, idx, system);
		}

	};
}