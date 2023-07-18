const std = @import("std");
const meta = @import("meta.zig");
const bin = std.builtin;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const BitSet = std.DynamicBitSetUnmanaged;
const StaticBitSet = std.StaticBitSet;


// Indices


pub const ComponentIndex = enum(u32) { _ };
pub const EntityIndex = enum(u32) { _ };


// Raw storages


pub fn ComponentStorage(
	comptime component_names: []const []const u8,
	comptime component_types: []const type
) type {
	var builder = meta.StructBuilder {};

	for( component_names, component_types ) |name, typ| {
		builder.addField(name, ArrayList(typ));
		builder.addField(name ++ "_owners", ArrayList(EntityIndex));
	}

	return @Type(builder.finish(false));
}

pub fn ResourceStorage(
	comptime resource_names: []const []const u8,
	comptime resource_types: []const type,
) type {
	var builder = meta.StructBuilder {};

	for( resource_names, resource_types ) |name, typ| {
		builder.addField(name, typ);
	}

	return @Type(builder.finish(false));
}

pub fn EntityStorage(
	comptime component_names: []const []const u8,
) type {
	var builder = meta.StructBuilder {};

	for( component_names ) |name| {
		builder.addField(name, ArrayList(?ComponentIndex));
	}

	return @Type(builder.finish(false));
}

pub fn ComponentUnion(
	comptime component_names: []const []const u8,
	comptime component_types: []const type,
) type {
	var builder = meta.UnionBuilder {};

	for( component_names, component_types ) |name, Type| {
		builder.addField(name, Type);
	}

	return @Type(builder.finish(ComponentEnum(component_names)));
}


// Enums


pub fn ComponentEnum(
	comptime component_names: []const []const u8,
) type {
	return @Type(meta.enumFromNames(component_names, u32));
}

pub fn ResourceEnum(
	comptime resource_names: []const []const u8,
) type {
	return @Type(meta.enumFromNames(resource_names, u32));
}


// Commands


pub fn CommandUnion(
	comptime component_names: []const []const u8,
	comptime component_types: []const type
) type {
	return union(enum) {
		const AnyComponent = ComponentUnion(component_names, component_types);
		const ComponentName = ComponentEnum(component_names);
		
		create_entity: u32,
		destroy_entity: EntityIndex,
		attach_component: AttachCommand,
		detach_component: DetachCommand,

		pub const AttachCommand = struct {
			entity: u32,
			// if true, entity represents the nth entity that will be created
			// if false, entity is an EntityIndex
			futur_entity: bool, 
			component: AnyComponent,
		};

		pub const DetachCommand = struct {
			entity: EntityIndex,
			component: ComponentName,
		};
	};
}

pub fn CommandBuffer(
	comptime component_names: []const []const u8,
	comptime component_types: []const type,
) type {
	return struct {
		pub const command_buffer = true;

		const Command = CommandUnion(component_names, component_types);
		const ComponentName = ComponentEnum(component_names);
		const Components = ComponentStore(component_names, component_types);
		const Entities = EntityStore(component_names);
		const AnyComponent = ComponentUnion(component_names, component_types);
		const Self = @This();

		alloc: Allocator,
		buffer: ArrayList(Command),
		created_entities: ArrayList(EntityIndex),

		// init/deinit

		pub fn init(
			self: *Self,
			alloc: Allocator,
			cap: usize
		) Allocator.Error!void {
			self.* = .{
				.alloc = alloc,
				.buffer = try ArrayList(Command).initCapacity(alloc, cap),
				.created_entities = try ArrayList(EntityIndex).initCapacity(alloc, cap),
			};
		}

		pub fn deinit(
			self: *Self,
		) void {
			self.buffer.deinit(self.alloc);
			self.created_entities.deinit(self.alloc);
		}

		pub fn reset(
			self: *Self,
		) void {
			self.buffer.shrinkRetainingCapacity(0);
			self.created_entities.shrinkRetainingCapacity(0);
		}

		// command execution

		pub fn execute(
			self: Self,
			components: *Components,
			entities: *Entities,
		) Allocator.Error!void {
			const cmds = self.buffer.items;

			for( cmds ) |cmd| {
				try self.executeCommand(cmd, components, entities);
			}
		}

		fn executeCommand(
			self: Self,
			cmd: Command,
			components: *Components,
			entities: *Entities
		) Allocator.Error!void {
			switch(cmd) {
				.create_entity => |idx| {
					const ent = try entities.insert(self.alloc);
					self.created_entities.items[idx] = ent;
				},
				.destroy_entity => |ent| {
					entities.remove(ent);
				},
				.attach_component => |ac| {
					if( comptime component_names.len == 0 )
						return;

					const ent: EntityIndex = if( ac.futur_entity )
						self.created_entities.items[ac.entity]
					else
						@enumFromInt(ac.entity);

					switch( ac.component ) {
						inline else => |val, name| {
							if( entities.getOwnership(ent, name) ) |cidx| {
								components.setComponent(name, cidx, val);
							} else {
								const cidx = try components.insert(self.alloc, name, val, ent);
								try entities.setOwnership(self.alloc, ent, name, cidx);
							}
						}
					}
				},
				.detach_component => |dc| {
					if( comptime component_names.len == 0 )
						return;

					switch( dc.component ) {
						inline else => |name| {
							const cidx = entities.getOwnership(dc.entity, name).?;
							try entities.setOwnership(self.alloc, dc.entity, name, null);

							if( components.remove(name, cidx) ) {
								const ent = components.getOwner(name, cidx);
								try entities.setOwnership(self.alloc, ent, name, cidx);
							}
						}
					}

				}
			}
		}

		// command queuing

		pub fn createEntity(
			self: *Self,
		) Allocator.Error!EntityCommandBuffer {
			const command = Command { 
				.create_entity = @intCast(self.created_entities.items.len) 
			};

			try self.buffer.append(self.alloc, command);
			try self.created_entities.append(self.alloc, undefined);

			return EntityCommandBuffer {
				.parent = self,
				.entity = command.create_entity
			};
		}

		pub fn destroyEntity(
			self: *Self,
			entity: EntityIndex
		) Allocator.Error!void {
			const command = Command {
				.destroy_entity = entity,
			};

			try self.buffer.append(self.alloc, command);
		}

		pub fn attachComponent(
			self: *Self,
			entity: EntityIndex,
			comptime name: ComponentName,
			value: Components.ComponentType(name)
		) Allocator.Error!void {
			const command = Command {
				.attach_component = .{
					.entity = @intFromEnum(entity),
					.futur_entity = false,
					.component = @unionInit(AnyComponent, @tagName(name), value),
				}
			};

			try self.buffer.append(self.alloc, command);
		}

		pub fn detachComponent(
			self: *Self,
			entity: EntityIndex,
			comptime name: ComponentName
		) Allocator.Error!void {
			const command = Command {
				.detach_component = .{
					.entity = entity,
					.component = name,
				}
			};

			try self.buffer.append(self.alloc, command);
		}

		pub const EntityCommandBuffer = struct {
			parent: *Self,
			entity: u32,

			pub fn attachComponent(
				self: EntityCommandBuffer,
				comptime name: ComponentName,
				value: Components.ComponentType(name)
			) Allocator.Error!void {
				const command = Command {
					.attach_component = .{
						.entity = self.entity,
						.futur_entity = true,
						.component = @unionInit(AnyComponent, @tagName(name), value),
					}
				};

				try self.parent.buffer.append(self.parent.alloc, command);
			}
		};
	};
}


// Stores


pub fn ComponentStore(
	comptime component_names: []const []const u8,
	comptime component_types: []const type
) type {
	return struct {
		const Storage = ComponentStorage(component_names, component_types);
		const ComponentName = ComponentEnum(component_names);
		const Self = @This();

		storage: Storage = undefined,

		// init/deinit

		pub fn init(
			self: *Self,
			alloc: Allocator,
			cap: usize,
		) Allocator.Error!void {
			inline for( component_names, component_types ) |name, typ| {
				if( @sizeOf(typ) > 0 )
					@field(self.storage, name) = try ArrayList(typ).initCapacity(alloc, cap)
				else 
					@field(self.storage, name) = .{};
				
				@field(self.storage, name ++ "_owners") = try ArrayList(EntityIndex).initCapacity(alloc, cap);
			}
		}

		pub fn deinit(
			self: *Self,
			alloc: Allocator
		) void {
			inline for( component_names, component_types ) |name, typ| {
				if( @sizeOf(typ) > 0 )
					@field(self.storage, name).deinit(alloc);
				
				@field(self.storage, name ++ "_owners").deinit(alloc);
			}
		}

		// memory management 

		pub fn compact(
			self: *Self,
			alloc: Allocator
		) void {
			inline for( component_names ) |name| {
				const len = @field(self.storage, name).items.len;
				@field(self.storage, name).shrinkAndFree(alloc, len);
				@field(self.storage, name ++ "_owners").shrinkAndFree(alloc, len);
			}
		}

		// Component arrays

		pub fn getComponentCount(
			self: *Self,
			comptime name: ComponentName
		) usize {
			return self.getComponentsConst(name).len;
		}

		pub fn getComponents(
			self: *Self,
			comptime name: ComponentName,
		) []ComponentType(name) {
			return @field(self.storage, @tagName(name)).items;
		}

		pub fn getComponentsConst(
			self: Self,
			comptime name: ComponentName,
		) []const ComponentType(name) {
			return @field(self.storage, @tagName(name)).items;
		}

		pub fn getComponentsDyn(
			self: *Self,
			name: ComponentName,
			comptime T: type,
		) []T {
			return switch(name) {
				inline else => |tag|
					self.getComponents(tag),
			};
		}

		pub fn getComponentsConstDyn(
			self: Self,
			name: ComponentName,
			comptime T: type,
		) []const T {
			return switch(name) {
				inline else => |tag|
					self.getComponentsConst(tag),
			};
		}

		// Owner arrays

		pub fn getOwners(
			self: *Self,
			comptime name: ComponentName,
		) []EntityIndex {
			return @field(self.storage, @tagName(name) ++ "_owners").items;
		}

		pub fn getOwnersConst(
			self: Self,
			comptime name: ComponentName,
		) []const EntityIndex {
			return @field(self.storage, @tagName(name) ++ "_owners").items;
		}
		
		pub fn getOwnersDyn(
			self: *Self,
			name: ComponentName
		) []EntityIndex {
			return switch(name) {
				inline else => |tag| 
					self.getOwners(tag),
			};
		}

		pub fn getOwnersConstDyn(
			self: Self,
			name: ComponentName,
		) []const EntityIndex {
			return switch(name) {
				inline else => |tag| 
					self.getOwnersConst(tag),
			};
		}

		// Single component

		pub fn getComponent(
			self: Self,
			comptime name: ComponentName,
			index: ComponentIndex,
		) ComponentType(name) {
			return self.getComponentsConst(name)[@intFromEnum(index)];
		}

		pub fn getComponentPtr(
			self: *Self,
			comptime name: ComponentName,
			index: ComponentIndex,
		) *ComponentType(name) {
			return &self.getComponents(name)[@intFromEnum(index)];
		}

		pub fn getComponentPtrConst(
			self: Self,
			comptime name: ComponentName,
			index: ComponentIndex,
		) *const ComponentType(name) {
			return &self.getComponentsConst(name)[@intFromEnum(index)];
		}

		pub fn setComponent(
			self: *Self,
			comptime name: ComponentName,
			index: ComponentIndex,
			value: ComponentType(name)
		) void {
			self.getComponents(name)[@intFromEnum(index)] = value;
		}

		// Single owner

		pub fn getOwner(
			self: Self,
			comptime name: ComponentName,
			index: ComponentIndex,
		) EntityIndex {
			return self.getOwnersConst(name)[@intFromEnum(index)];
		}

		pub fn setOwner(
			self: *Self,
			comptime name: ComponentName,
			index: ComponentIndex,
			owner: EntityIndex
		) void {
			self.getOwners(name)[@intFromEnum(index)] = owner;
		}

		// Insertion and removal

		pub fn insert(
			self: *Self,
			alloc: Allocator,
			comptime name: ComponentName,
			value: ComponentType(name),
			owner: EntityIndex,
		) Allocator.Error!ComponentIndex {
			var storage = &@field(self.storage, @tagName(name));

			try storage.append(alloc, value);
			try @field(self.storage, @tagName(name) ++ "_owners").append(alloc, owner);

			const cidx: u32 = @intCast(storage.items.len - 1);
			return @enumFromInt(cidx);
		}

		/// Returns true if the removal changed the index of a component.
		pub fn remove(
			self: *Self,
			comptime name: ComponentName,
			index: ComponentIndex,
		) bool {
			const idx = @intFromEnum(index);
			var storage = &@field(self.storage, @tagName(name));

			_ = @field(self.storage, @tagName(name) ++ "_owners").swapRemove(idx);
			_ = storage.swapRemove(idx);

			return if( storage.items.len == idx )
				false
			else
				true;
		}

		// Comptime utilities

		pub fn ComponentType(
			comptime name: ComponentName
		) type {
			return component_types[@intFromEnum(name)];
		}
	};
}

pub fn ResourceStore(
	comptime resource_names: []const []const u8,
	comptime resource_types: []const type
) type {
	return struct {
		const ResourceName = ResourceEnum(resource_names);
		const Self = @This();

		storage: ResourceStorage(resource_names, resource_types) = undefined,
		initialized: StaticBitSet(resource_names.len) = StaticBitSet(resource_names.len).initEmpty(),

		// Initialization state

		pub fn isInitialized(
			self: Self,
			comptime name: ResourceName
		) bool {
			return self.initialized.isSet(@intFromEnum(name));
		}

		// Getters

		pub fn get(
			self: Self,
			comptime name: ResourceName
		) ResourceType(name) {
			return @field(self.storage, @tagName(name));
		}

		pub fn getPtr(
			self: *Self,
			comptime name: ResourceName,
		) *ResourceType(name) {
			return &@field(self.storage, @tagName(name));
		}

		pub fn getPtrConst(
			self: Self,
			comptime name: ResourceName
		) *const ResourceType(name) {
			return &@field(self.storage, @tagName(name));
		}

		// Setters

		pub fn set(
			self: *Self,
			comptime name: ResourceName,
			value: ResourceType(name)
		) void {
			@field(self.storage, @tagName(name)) = value;
			self.initialized.set(@intFromEnum(name));
		}

		// Getter/setting utilities

		pub fn getOrSet(
			self: *Self,
			comptime name: ResourceName,
			value: ResourceType(name),
		) ResourceType(name) {
			if( self.isInitialized(name) ) {
				return self.get(name);
			} else {
				self.set(name, value);
				return value;
			}
		}

		// Comptime utilities

		pub fn ResourceType(
			comptime name: ResourceName
		) type {
			return resource_types[@intFromEnum(name)];
		}
	};
}

pub fn EntityStore(
	comptime component_names: []const []const u8,
) type {
	return struct {
		const Storage = EntityStorage(component_names);
		const ComponentName = ComponentEnum(component_names);
		const Self = @This();

		storage: Storage = undefined,
		generations: ArrayList(u32) = .{},
		alives: BitSet = .{},
		free: usize = 0,

		// init/deinit

		pub fn init(
			self: *Self,
			alloc: Allocator,
			cap: usize
		) Allocator.Error!void {
			self.generations = try ArrayList(u32).initCapacity(alloc, cap);
			self.alives = try BitSet.initEmpty(alloc, cap);
			self.free = 0;

			inline for( component_names ) |name| {
				@field(self.storage, name) = try ArrayList(?ComponentIndex).initCapacity(alloc, cap);
			}
		}

		pub fn deinit(
			self: *Self,
			alloc: Allocator,
		) void {
			self.generations.deinit(alloc);
			self.alives.deinit(alloc);

			inline for( component_names ) |name| {
				@field(self.storage, name).deinit(alloc);
			}
		}

		// Entity's alive flag

		pub fn isAlive(
			self: Self,
			entity: EntityIndex,
		) bool {
			const idx = @intFromEnum(entity);
			return self.alives.isSet(idx);
		}

		pub fn setAlive(
			self: *Self,
			entity: EntityIndex,
			alive: bool
		) void {
			const idx = @intFromEnum(entity);
			
			if( alive )
				self.alives.set(idx)
			else
				self.alives.unset(idx);
		}

		// Entity's generation

		pub fn getGeneration(
			self: Self,
			entity: EntityIndex,
		) u32 {
			return self.generations.items[@intFromEnum(entity)];
		}

		// Ownership arrays

		pub fn getOwnerships(
			self: *Self,
			comptime name: ComponentName,
		) []?ComponentIndex {
			return @field(self.storage, @tagName(name)).items;
		}

		pub fn getOwnershipsDyn(
			self: *Self,
			name: ComponentName,
		) []?ComponentIndex {
			return switch(name) {
				inline else => |tag|
					self.getOwnerships(tag),
			};
		}

		pub fn getOwnershipsConst(
			self: Self,
			comptime name: ComponentName,
		) []const ?ComponentIndex {
			return @field(self.storage, @tagName(name)).items;
		}

		pub fn getOwnershipsConstDyn(
			self: Self,
			name: ComponentName,
		) []const ?ComponentIndex {
			return switch(name) {
				inline else => |tag|
					self.getOwnershipsConst(tag),
			};
		}

		// Single ownership

		pub fn getOwnership(
			self: Self,
			entity: EntityIndex,
			comptime name: ComponentName,
		) ?ComponentIndex {
			const idx = @intFromEnum(entity);
			const ownerships = self.getOwnershipsConst(name);

			// required as ownership arrays are grown in `setOwnership`
			return if( idx < ownerships.len )
				ownerships[idx]
			else
				null;
		}

		pub fn getOwnershipDyn(
			self: Self,
			entity: EntityIndex,
			name: ComponentName,
		) ?ComponentIndex {
			const idx = @intFromEnum(entity);
			const ownerships = self.getOwnershipsConstDyn(name);

			// required as ownership arrays are grown in `setOwnership`
			return if( idx < ownerships.len )
				ownerships[idx]
			else
				null;
		}

		
		pub fn setOwnership(
			self: *Self,
			alloc: Allocator,
			entity: EntityIndex,
			comptime name: ComponentName,
			component: ?ComponentIndex
		) Allocator.Error!void {
			const idx = @intFromEnum(entity);
			var array = &@field(self.storage, @tagName(name));

			if( array.items.len <= idx ) {
				const previous_len = array.items.len;
				try array.resize(alloc, idx + 1);

				@memset(array.items[previous_len..], null);
			}

			array.items[idx] = component;
		}

		// insertion and removal

		pub fn insert(
			self: *Self,
			alloc: Allocator,
		) Allocator.Error!EntityIndex {
			if( self.free > 0 ) {
				// if they are some free entity slots we use them
				var idx: u32 = 0;

				for( 0..self.generations.items.len ) |i| {
					if( !self.alives.isSet(i) ) {
						idx = @intCast(i);
						break;
					}
				}

				self.free -= 1;
				self.alives.set(idx);
				return @enumFromInt(idx);
			} else {
				// otherwise we need to allocate a new slot
				const curr_len: u32 = @intCast(self.generations.items.len);

				if( self.alives.capacity() < curr_len + 1 )
					try self.alives.resize(alloc, self.alives.capacity()*2, false);
				
				self.alives.set(curr_len);
				try self.generations.append(alloc, 0);

				return @enumFromInt(curr_len);
			}
		}

		pub fn remove(
			self: *Self,
			entity: EntityIndex
		) void {
			const idx = @intFromEnum(entity);

			self.alives.unset(idx);
			self.generations.items[idx] += 1;
			self.free += 1;

			inline for( 0..component_names.len ) |i| {
				const cidx: u32 = @intCast(i);
				const name: ComponentName = @enumFromInt(cidx);

				var ownerships = self.getOwnerships(name);

				if( idx < ownerships.len )
					ownerships[idx] = null;
			}
		}
	};
}
