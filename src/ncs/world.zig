const std = @import("std");
const storage = @import("storage.zig");
const sys = @import("system.zig");
const schedule = @import("schedule.zig");

const Allocator = std.mem.Allocator;



pub fn World(
	comptime desc: anytype
) type {
	return struct {
		pub const descriptor = expandedDescriptor(desc);

		pub const ComponentIndex = storage.ComponentIndex;
		pub const EntityIndex = storage.EntityIndex;
		pub const Entity = EntityRef;
		pub const ComponentName = storage.ComponentEnum(descriptor.component_names);
		pub const ResourceName = storage.ResourceEnum(descriptor.resource_names);
		pub const ComponentStore = storage.ComponentStore(descriptor.component_names, descriptor.component_types);
		pub const ResourceStore = storage.ResourceStore(descriptor.resource_names, descriptor.resource_types);
		pub const EntityStore = storage.EntityStore(descriptor.component_names);
		pub const CommandBuffer = storage.CommandBuffer(descriptor.component_names, descriptor.component_types);

		pub const Imut = sys.Imut;
		pub const Mut = sys.Mut;
		pub const With = sys.With;
		pub const Without = sys.Without;
		pub const Res = SystemImpl.Res;
		pub const ResMut = SystemImpl.ResMut;
		pub const Query = SystemImpl.Query;
		pub const System = SystemImpl.System;

		pub const StageName = schedule.StageEnum(descriptor.stages);
		pub const ScheduleStore = schedule.ScheduleStore(SystemImpl, descriptor.stages);

		const SystemImpl = sys.SystemImpl(descriptor.component_names, descriptor.component_types, descriptor.resource_names, descriptor.resource_types);
		const Self = @This();



		alloc: Allocator,
		components: ComponentStore,
		resources: ResourceStore,
		entities: EntityStore,
		schedules: ScheduleStore,
		command_buffer: CommandBuffer,

		// init/deinit

		pub fn init(
			self: *Self,
			alloc: Allocator,
			component_cap: usize,
			entity_cap: usize,
			schedule_cap: usize,
			command_cap: usize,
		) Allocator.Error!void {
			self.alloc = alloc;
			try self.components.init(alloc, component_cap);
			self.resources = .{};
			try self.entities.init(alloc, entity_cap);
			try self.schedules.init(alloc, schedule_cap);
			try self.command_buffer.init(alloc, command_cap);

			inline for( descriptor.plugins ) |Plugin| {
				if( comptime @hasDecl(Plugin, "init") ) {
					try Plugin.init(self);
				}
			}
		}

		pub fn deinit(
			self: *Self,
		) void {
			inline for( descriptor.plugins ) |Plugin| {
				if( comptime @hasDecl(Plugin, "deinit") ) {
					Plugin.deinit(self);
				}
			}

			self.command_buffer.deinit();
			self.schedules.deinit(self.alloc);
			self.components.deinit(self.alloc);
			self.entities.deinit(self.alloc);
		}

		// resources

		pub fn getResource(
			self: Self,
			comptime name: ResourceName,
		) ResourceStore.ResourceType(name) {
			return self.resources.get(name);
		}

		pub fn setResource(
			self: *Self,
			comptime name: ResourceName,
			value: ResourceStore.ResourceType(name),
		) void {
			self.resources.set(name, value);
		}

		// entities

		pub fn createEntity(
			self: *Self
		) Allocator.Error!Entity {
			const idx = try self.entities.insert(self.alloc);
			return Entity {
				.index = idx,
				.generation = self.entities.getGeneration(idx),
			};
		}

		pub fn destroyEntity(
			self: *Self,
			entity: Entity
		) void {
			const idx = entity.index;
			const gen = entity.generation;

			if( !self.entities.isAlive(idx) or self.entities.getGeneration(idx) != gen ) 
				return;
			
			inline for( 0..descriptor.component_names.len ) |i| {
				const cidx: u32 = @intCast(i);
				const name: ComponentName = @enumFromInt(cidx);

				if( self.entities.getOwnership(idx, name) ) |comp| {
					if( self.components.remove(name, comp) ) {
						// here `comp` is the still alive as now it is the component
						// that was at the end of the component array. so gotta 
						// do some book keeping and update the entity's ownership
						const ent = self.components.getOwner(name, comp);
						try self.entities.setOwnership(self.alloc, ent, name, comp);
					}
				}
			}

			self.entities.remove(idx);
		}

		pub fn isEntityAlive(
			self: Self,
			entity: Entity
		) bool {
			return self.entities.isAlive(entity.index) and 
				self.entities.getGeneration(entity.index) == entity.generation;
		}

		pub fn attachComponent(
			self: *Self,
			entity: Entity,
			comptime name: ComponentName,
			value: ComponentStore.ComponentType(name),
		) Allocator.Error!void {
			if( !self.isEntityAlive(entity) )
				return;

			const idx = entity.index;
			
			if( self.entities.getOwnership(idx, name) ) |cidx| {
				self.components.setComponent(name, cidx, value);
			} else {
				const cidx = try self.components.insert(self.alloc, name, value, idx);
				try self.entities.setOwnership(self.alloc, idx, name, cidx);
			}
		}

		// schedule

		pub fn addSystem(
			self: *Self,
			comptime name: StageName,
			comptime func: anytype
		) Allocator.Error!void {
			const system = System.from(func);
			try self.schedules.insertAfterAll(self.alloc, name, system);
		}

		pub fn addSystemAtStart(
			self: *Self,
			comptime name: StageName,
			comptime func: anytype
		) Allocator.Error!void {
			const system = System.from(func);
			try self.schedules.insertBeforeAll(self.alloc, name, system);
		}

		pub fn addSystemAfter(
			self: *Self,
			comptime name: StageName,
			comptime func: anytype,
			after: *const anyopaque,
		) Allocator.Error!void {
			const system = System.From(func);
			try self.schedules.insertAfter(self.alloc, name, system, @intFromPtr(after));
		}

		pub fn addSystemBefore(
			self: *Self,
			comptime name: StageName,
			comptime func: anytype,
			before: *const anyopaque,
		) Allocator.Error!void {
			const system = System.from(func);
			try self.schedules.insertBefore(self.alloc, name, system, @intFromPtr(before));
		}

		pub fn run(
			self: *Self,
			comptime name: StageName
		) anyerror!void {
			try self.schedules.run(name, &self.components, &self.resources, &self.entities, &self.command_buffer);
		}
	};
}



pub const ExpandedDescriptor = struct {
	plugins: []const type,
	component_names: []const []const u8,
	component_types: []const type,
	resource_names: []const []const u8,
	resource_types: []const type,
	stages: []const []const u8,
};

pub fn expandedDescriptor(
	comptime desc: anytype
) ExpandedDescriptor {
	const Desc = @TypeOf(desc);

	var component_names: []const []const u8 = &.{};
	var component_types: []const type = &.{};
	var resource_names: []const []const u8 = &.{};
	var resource_types: []const type = &.{};
	var stages: []const []const u8 = &.{};

	var all_plugins: []const type = if( @hasField(Desc, "plugins") )
		getAllPlugins(desc.plugins)
	else
		&.{};
	
	// gathering plugin stuff first
	for( all_plugins ) |Plugin| {
		// gathering components
		if( @hasDecl(Plugin, "ncs_components") ) {
			const plugin_comps = Plugin.ncs_components;
			const PluginComps = @TypeOf(plugin_comps);

			for( @typeInfo(PluginComps).Struct.fields ) |field| {
				if( findName(component_names, field.name) ) |idx| {
					_ = idx; // TODO: check if both types are equal, errors if they arent
				} else {
					component_names = component_names ++ &[1][]const u8 { field.name };
					component_types = component_types ++ &[1]type { @field(plugin_comps, field.name) };
				}
			}
		}

		// gathering resources
		if( @hasDecl(Plugin, "ncs_resources") ) {
			const plugin_res = Plugin.ncs_resources;
			const PluginRes = @TypeOf(plugin_res);

			for( @typeInfo(PluginRes).Struct.fields ) |field| {
				if( findName(resource_names, field.name) ) |idx| {
					_ = idx; // TODO: check if both types are equal, errors if they arent
				} else {
					resource_names = resource_names ++ &[1][]const u8 { field.name };
					resource_types = resource_types ++ &[1]type { @field(plugin_res, field.name) };
				}
			}
		}

		// gathering stages
		if( @hasDecl(Plugin, "ncs_stages") ) {
			const plugin_stages = Plugin.ncs_stages;

			for( plugin_stages ) |stage| {
				if( findName(stages, @tagName(stage)) == null ) {
					stages = stages ++ &[1][]const u8 { @tagName(stage) };
				}
			}
		}
	}

	// gathering descriptor's stuff

	// components
	if( @hasField(Desc, "components") ) {
		const desc_comps = desc.components;
		const DescComps = @TypeOf(desc_comps);

		for( @typeInfo(DescComps).Struct.fields ) |field| {
			if( findName(component_names, field.name) ) |idx| {
				_ = idx; // TODO: check if both types are equal, errors if they arent
			} else {
				component_names = component_names ++ &[1][]const u8 { field.name };
				component_types = component_types ++ &[1]type { @field(desc_comps, field.name) };
			}
		}
	}

	// gathering resources
	if( @hasField(Desc, "resources") ) {
		const desc_res = desc.resources;
		const DescRes = @TypeOf(desc_res);

		for( @typeInfo(DescRes).Struct.fields ) |field| {
			if( findName(resource_names, field.name) ) |idx| {
				_ = idx; // TODO: check if both types are equal, errors if they arent
			} else {
				resource_names = resource_names ++ &[1][]const u8 { field.name };
				resource_types = resource_types ++ &[1]type { @field(desc_res, field.name) };
			}
		}
	}

	// gathering stages
	if( @hasField(Desc, "stages") ) {
		const desc_stages = desc.stages;

		for( desc_stages ) |stage| {
			if( findName(stages, @tagName(stage)) == null ) {
				stages = stages ++ &[1][]const u8 { @tagName(stage) };
			}
		}
	}

	return .{
		.plugins = all_plugins,
		.component_names = component_names,
		.component_types = component_types,
		.resource_names = resource_names,
		.resource_types = resource_types,
		.stages = stages,
	};
}

fn getAllPlugins(
	comptime plugins: anytype
) []const type {
	var result: []const type = &.{};

	for( plugins ) |Plugin| {
		if( @hasDecl(Plugin, "ncs_plugins") )
			result = result ++ getAllPlugins(Plugin.ncs_plugins);
	}

	return result ++ plugins;
}

fn findName(
	comptime names: []const []const u8,
	comptime name: []const u8,
) ?usize {
	for( names, 0.. ) |n, i| {
		if( std.mem.eql(u8, name, n) )
			return i;
	}

	return null;
}


const EntityRef = packed struct(u64) {
	index: storage.EntityIndex,
	generation: u32,
};
