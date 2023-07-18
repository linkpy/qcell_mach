const std = @import("std");
const bin = std.builtin;
const meta = @import("meta.zig");
const storage = @import("storage.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const ComponentStore = storage.ComponentStore;
const ResourceStore = storage.ResourceStore;
const EntityStore = storage.EntityStore;


// Param modifiers


pub fn Imut(
	comptime p: anytype,
) type {
	return struct {
		pub const param_modifier = ParamModifier.imut;
		pub const param = p;
	};
}

pub fn Mut( 
	comptime p: anytype,
) type {
	return struct {
		pub const param_modifier = ParamModifier.mut;
		pub const param = p;
	};
}

pub fn With(
	comptime p: anytype,
) type {
	return struct {
		pub const param_modifier = ParamModifier.with;
		pub const param = p;
	};
}

pub fn Without(
	comptime p: anytype,
) type {
	return struct {
		pub const param_modifier = ParamModifier.without;
		pub const param = p;
	};
}


// System dependencies


pub fn SystemDependencies(
	comptime component_names: []const []const u8,
	comptime resource_names: []const []const u8,
) type {
	return struct {
		pub const ComponentName = storage.ComponentEnum(component_names);
		pub const ResourceName = storage.ResourceEnum(resource_names);

		const Self = @This();

		read_components: []const ComponentName = &.{},
		write_components: []const ComponentName = &.{},
		with_components: []const ComponentName = &.{},
		without_components: []const ComponentName = &.{},
		read_resources: []const ResourceName = &.{},
		write_resources: []const ResourceName = &.{},
		commands: bool = false,

		// Creation

		fn fromQuery(
			comptime q: anytype,
		) Self {
			var res = Self {};

			// TODO: checks for duplicates
			// TODO: checks for conficts (With(.a) and Without(.a) at the same time, etc)

			for( q ) |entry| {
				const Param = @TypeOf(entry);

				if( isTuple(Param) ) {
					res.extend(fromQuery(entry));

				} else if( Param == type and isParamModifier(entry) ) {
					switch( entry.param_modifier ) {
						.res, .resmut =>
							@compileError("Resource parameters arent allowed in queries."),
						else => 
							res.add(entry),
					}

				} else if( isEnumLiteral(Param) ) {
					res.add(Imut(entry));

				} else if( isCommandBuffer(Param) ) {
					res.commands = true;

				} else {
					@compileError("Only component names, Mut(c), With(c), Without(c), or tuples are allowed in a query.");
				}
			}

			return res;
		}

		// Modifying

		pub fn extend(
			comptime self: *Self,
			comptime other: Self,
		) void {
			self.read_components = self.read_components ++ other.read_components;
			self.write_components = self.write_components ++ other.write_components;
			self.with_components = self.with_components ++ other.with_components;
			self.without_components = self.without_components ++ other.without_components;
			self.read_resources = self.read_resources ++ other.read_resources;
			self.write_resources = self.write_resources ++ other.write_resources;
			self.commands = self.commands or other.commands;
		}

		pub fn add(
			comptime self: *Self,
			comptime Param: type,
		) void {
			switch( Param.param_modifier ) {
				.imut => 
					self.read_components = self.read_components ++ &[1]ComponentName { Param.param },
				.mut => 
					self.write_components = self.write_components ++ &[1]ComponentName { Param.param },
				.with => 
					self.with_components = self.with_components ++ &[1]ComponentName { Param.param },
				.without =>
					self.without_components = self.without_components ++ &[1]ComponentName { Param.param },
				.res =>
					self.read_resources = self.read_resources ++ &[1]ResourceName { Param.param },
				.resmut =>
					self.write_resources = self.write_resources ++ &[1]ResourceName { Param.param },
			}
		}

		// Accesses

		pub fn getAllPresentComponents(
			comptime self: Self,
		) []const ComponentName {
			return 
				self.read_components ++
				self.write_components ++
				self.with_components;
		}

		// Checks
	
		pub fn hasComponentRead(
			comptime self: Self,
			comptime name: ComponentName,
		) bool {
			// if a component is written to, it can also be readed
			const comps = self.read_components ++ self.write_components;
			for( comps ) |comp| {
				if( comp == name )
					return true;
			}

			return false;
		}

		pub fn hasComponentWrite(
			comptime self: Self,
			comptime name: ComponentName,
		) bool {
			for( self.write_components ) |comp| {
				if( comp == name )
					return true;
			}

			return false;
		}

		pub fn hasResourceRead(
			comptime self: Self,
			comptime name: ResourceName,
		) bool {
			// if a resource is written to, it can also be readed
			const resources = self.read_resources ++ self.write_resources;
			for( resources ) |res| {
				if( res == name )
					return true;
			}

			return false;
		}

		pub fn hasResourceWrite(
			comptime self: Self,
			comptime name: ResourceName,
		) bool {
			for( self.write_resources ) |res| {
				if( res == name )
					return true;
			}

			return false;
		}
	};
}


// Query


pub fn queryImpl(
	comptime component_names: []const []const u8,
	comptime component_types: []const type,
	comptime resource_names: []const []const u8,
) fn(comptime q: anytype) type {
	return struct {
		const ComponentName = storage.ComponentEnum(component_names);
		const Components = ComponentStore(component_names, component_types);
		const Entities = EntityStore(component_names);
		const Dependencies = SystemDependencies(component_names, resource_names);
		const EntityIndex = storage.EntityIndex;



		fn Entry(
			comptime query_dependencies: Dependencies
		) type {
			return struct {
				const Self = @This();

				components: *Components,
				entities: *Entities,

				entity: EntityIndex,

				pub fn get(
					self: Self,
					comptime comp: ComponentName,
				) Components.ComponentType(comp) {
					if( comptime !query_dependencies.hasComponentRead(comp) )
						@compileError("Component '" ++ @tagName(comp) ++ "' wasnt defined as readable in the Query.");

					const idx = self.entities.getOwnership(self.entity, comp).?;
					return self.components.getComponent(comp, idx);
				}

				pub fn getPtr(
					self: Self,
					comptime comp: ComponentName,
				) *Components.ComponentType(comp) {
					if( comptime !query_dependencies.hasComponentWrite(comp) ) 
						@compileError("Component '" ++ @tagName(comp) ++ "' wasnt defined as writable in the Query.");

					const idx = self.entities.getOwnership(self.entity, comp).?;
					return self.components.getComponentPtr(comp, idx);
				}

				pub fn set(
					self: Self,
					comptime comp: ComponentName,
					value: Components.ComponentType(comp)
				) void {
					if( comptime !query_dependencies.hasComponentWrite(comp) )
						@compileError("Component '" ++ @tagName(comp) ++ "' wasnt defined as writable in the Query.");
					
					const idx = self.entities.getOwnership(self.entity, comp).?;
					self.components.setComponent(comp, idx, value);
				}
			};
		}

		fn Iterator(
			comptime query_dependencies: Dependencies
		) type {
			return struct {
				const Self = @This();

				components: *Components,
				entities: *Entities,
				selected_row: ComponentName,
				index: usize = 0,

				pub fn next(
					self: *Self
				) ?Entry(query_dependencies) {
					const owners = self.components.getOwnersConstDyn(self.selected_row);

					loop: while(self.index < owners.len) : (self.index += 1) {
						const entity = owners[self.index];

						inline for( comptime query_dependencies.getAllPresentComponents() ) |name| {
							if( self.entities.getOwnership(entity, name) == null )
								continue :loop;
						}

						inline for( query_dependencies.without_components ) |name| {
							if( self.entities.getOwnership(entity, name) != null )
								continue :loop;
						}

						self.index += 1;
						return Entry(query_dependencies) {
							.components = self.components,
							.entities = self.entities,
							.entity = entity,
						};
					}

					return null;
				}
			};
		}

		fn Impl(
			comptime q: anytype
		) type {
			return struct {
				pub const query_dependencies = Dependencies.fromQuery(q);
				const Self = @This();

				components: *Components,
				entities: *Entities,
				selected_row: ComponentName,

				pub fn init(
					components: *Components,
					entities: *Entities,
				) Self {
					var selected_count: usize = std.math.maxInt(usize);
					var selected: ComponentName = undefined;
					
					inline for( comptime query_dependencies.getAllPresentComponents() ) |comp| {
						const count = components.getComponentCount(comp);
						if( count < selected_count ) {
							selected = @as(ComponentName, comp);
							selected_count = count;
						}
					}

					return .{
						.components = components,
						.entities = entities,
						.selected_row = selected,
					};
				}
			
				pub fn iter(
					self: Self
				) Iterator(query_dependencies) {
					return .{
						.components = self.components,
						.entities = self.entities,
						.selected_row = self.selected_row,
					};
				}
			};
		}
	}.Impl;
}

pub fn SystemImpl(
	comptime component_names: []const []const u8,
	comptime component_types: []const type,
	comptime resource_names: []const []const u8,
	comptime resource_types: []const type,
) type {
	return struct {
		const ComponentName = storage.ComponentEnum(component_names);
		const ResourceName = storage.ResourceEnum(resource_names);
		pub const Components = ComponentStore(component_names, component_types);
		pub const Resources = ResourceStore(resource_names, resource_types);
		pub const Entities = EntityStore(component_names);
		pub const Query = queryImpl(component_names, component_types, resource_names);
		pub const Dependencies = SystemDependencies(component_names, resource_names);
		pub const CommandBuffer = storage.CommandBuffer(component_names, component_types);



		pub fn Res(
			comptime p: ResourceName,
		) type {
			return struct {
				pub const param_modifier = ParamModifier.res;
				pub const param = p;

				res: Resources.ResourceType(p),
			};
		}

		pub fn ResMut(
			comptime p: anytype,
		) type {
			return struct {
				pub const param_modifier = ParamModifier.resmut;
				pub const param = p;

				res: *Resources.ResourceType(p),
			};
		}



		// pub const Parameter = union(enum) {
		// 	res: ResourceName,
		// 	res_mut: ResourceName,
		// 	query: type,
		// };

		pub fn systemRunner(
			comptime func: anytype
		) *const fn(*Components, *Resources, *Entities, *CommandBuffer) anyerror!void {
			return struct {
				pub fn run(
					comps: *Components, 
					res: *Resources,
					ents: *Entities,
					cmdbuf: *CommandBuffer,
				) !void {
					const Fn = @typeInfo(@TypeOf(func)).Pointer.child;
					const fn_info = @typeInfo(Fn).Fn;

					var args: std.meta.ArgsTuple(Fn) = undefined;

					inline for( fn_info.params, 0.. ) |param, i| {
						const Param = param.type.?;

						if( comptime isQuery(Param) ) {
							args[i] = param.type.?.init(comps, ents);

						} else if( comptime isParamModifier(Param) ) {
							// TODO: validate readable/writable resources are initialized
							switch(param.type.?.param_modifier) {
								.res => 
									args[i] = .{ .res = res.get(param.type.?.param)	},
								.resmut => 
									args[i] = .{ .res = res.getPtr(param.type.?.param) },
								else => 
									@compileError("Only Res, ResMut, and Query are accepted as System parameters."),
							}

						} else if( comptime isCommandBuffer(Param) ) {
							args[i] = cmdbuf;

						} else {
							@compileError("Only Res, ResMut, and Query are accepted as System parameters.");
						}
					}

					try @call(.auto, func, args);
				}
			}.run;
		}


		pub const System = struct {
			run: *const fn(*Components, *Resources, *Entities, *CommandBuffer) anyerror!void,
			dependencies: Dependencies,
			function: usize,



			pub fn from(
				comptime func: anytype,
			) System {
				var res = comptime blk: {
					const runner = systemRunner(func);
					var deps = Dependencies {};

					const Fn = @typeInfo(@TypeOf(func)).Pointer.child;
					const params = @typeInfo(Fn).Fn.params;

					for( params ) |param| {
						const Param = param.type.?;

						if( isQuery(Param) ) {
							deps.extend(Param.query_dependencies);
						} else if( isParamModifier(Param) ) {
							deps.add(Param);
						} else if( isCommandBuffer(Param) ) {
							deps.commands = true;
						}
					}

					break :blk System {
						.run = runner,
						.dependencies = deps,
						.function = 0,
					};
				};

				res.function = @intFromPtr(func);
				return res;
			}
		};
	};
}



const ParamModifier = enum {
	imut, mut,
	with, without,
	res, resmut,
};



fn isTuple(comptime T: type) bool {
	const info = @typeInfo(T);
	return info == .Struct and info.Struct.is_tuple;
}

fn isEnumLiteral(comptime T: type) bool {
	return @typeInfo(T) == .EnumLiteral;
}

fn isParamModifier(comptime T: type) bool {
	const info = @typeInfo(T);
	return info == .Struct and @hasDecl(T, "param_modifier") and @hasDecl(T, "param");
}

fn isQuery(comptime T: type) bool {
	const info = @typeInfo(T);
	return info == .Struct and @hasDecl(T, "query_dependencies");
}

fn isCommandBuffer(comptime T: type) bool {
	const info = @typeInfo(T);
	return info == .Pointer and 
		@typeInfo(info.Pointer.child) == .Struct and
		@hasDecl(info.Pointer.child, "command_buffer");
}