const std = @import("std");
const bin = std.builtin;



pub const StructBuilder = struct {
	fields: []const bin.Type.StructField = &.{},

	pub fn addField(
		comptime self: *StructBuilder,
		comptime name: []const u8,
		comptime Type: type
	) void {
		self.fields = self.fields ++ [1]bin.Type.StructField { .{
			.name = name,
			.type = Type,
			.default_value = null,
			.is_comptime = false,
			.alignment = @alignOf(Type)
		}};
	}

	pub fn finish(
		comptime self: StructBuilder,
		comptime tuple: bool
	) bin.Type {
		return .{ .Struct = .{
			.layout = .Auto,
			.backing_integer = null,
			.fields = self.fields,
			.decls = &.{},
			.is_tuple = tuple,
		}};
	}
};

pub const EnumBuilder = struct {
	fields: []const bin.Type.EnumField = &.{},
	next_value: comptime_int = 0,

	pub fn addField(
		comptime self: *EnumBuilder,
		comptime name: []const u8,
		comptime value: ?comptime_int
	) void {
		self.fields = self.fields ++ [1]bin.Type.EnumField { .{
			.name = name,
			.value = value orelse self.next_value,
		}};

		if( value == null )
			self.next_value += 1;
	}

	pub fn finish(
		comptime self: EnumBuilder,
		comptime Tag: type,
		comptime exhaustive: bool,
	) bin.Type {
		return .{ .Enum = .{
			.tag_type = Tag,
			.fields = self.fields,
			.decls = &.{},
			.is_exhaustive = exhaustive,
		}};
	}
};

pub const UnionBuilder = struct {
	fields: []const bin.Type.UnionField = &.{},
	next_value: comptime_int = 0,

	pub fn addField(
		comptime self: *UnionBuilder,
		comptime name: []const u8,
		comptime Type: type
	) void {
		self.fields = self.fields ++ [1]bin.Type.UnionField { .{
			.name = name,
			.type = Type,
			.alignment = @alignOf(Type),
		}};
	}

	pub fn finish(
		comptime self: UnionBuilder,
		comptime Tag: ?type,
	) bin.Type {
		return .{ .Union = .{
			.layout = .Auto,
			.tag_type = Tag,
			.fields = self.fields,
			.decls = &.{},
		}};
	}
};

pub fn enumFromNames(
	comptime names: []const []const u8,
	comptime Tag: type,
) bin.Type {
	var builder = EnumBuilder {};

	for( names, 0.. ) |name, i| {
		builder.addField(name, i);
	}

	return builder.finish(Tag, true);
}