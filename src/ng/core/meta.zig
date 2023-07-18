const std = @import("std");


pub fn reprType(
	comptime T: type
) []const u8 {
	comptime {
		return switch(@typeInfo(T)) {
			.Type,
			.Void,
			.Bool,
			.NoReturn,
			.Int,
			.Float,
			.Pointer,
			.Array,
			.ComptimeFloat,
			.ComptimeInt,
			.Undefined,
			.Null,
			.Optional,
			.Fn,
			.Opaque,
			.Frame,
			.AnyFrame,
			.Vector,
			.EnumLiteral,
			.ErrorUnion => reprTypeName(T),
			.Struct => |info| reprStruct(info),
			.ErrorSet => |info| reprErrorSet(info),
			.Enum => |info| reprEnum(info),
			.Union => |info| reprUnion(info),
		};
	}
}

pub fn reprTypeName(
	comptime T: type
) []const u8 {
	return @typeName(T);
}

pub fn reprStructField(
	comptime info: std.builtin.Type.StructField
) []const u8 {
	comptime {
		return std.fmt.comptimePrint("{s}{s}: {s} align({})", .{
			if( info.is_comptime ) "comptime" else "",
			info.name,
			reprTypeName(info.type),
			info.alignment
		});
	}
}

pub fn reprStruct(
	comptime info: std.builtin.Type.Struct
) []const u8 {
	comptime {
		var repr: []const u8 = std.fmt.comptimePrint("{s}struct {{\n", .{
			switch( info.layout ) {
				.Auto => "",
				.Extern => "extern ",
				.Packed => std.fmt.comptimePrint("packed({}) ", .{info.backing_integer.?}),
			}
		});

		for( info.fields ) |field| {
			repr = repr ++ "    " ++ reprStructField(field) ++ ",\n";
		}

		return repr ++ "}";
	}
}

pub fn reprErrorSet(
	comptime optinfo: std.builtin.Type.ErrorSet
) []const u8 {
	comptime {
		if( optinfo ) |info| {
			var repr: []const u8 = "error {{\n";

			for( info ) |err| {
				repr = repr ++ "    " ++ err.name ++ "\n";
			}

			return repr ++ "}";
		} else
			return "error {}";
	}
}

pub fn reprEnum(
	comptime info: std.builtin.Type.Enum
) []const u8 {
	comptime {
		var repr: []const u8 = "enum(" ++ @typeName(info.tag_type) ++ ") {\n";

		for( info.fields ) |field| {
			repr = repr ++ std.fmt.comptimePrint("    {s}: {},\n", .{
				field.name, field.value
			});
		}

		return repr ++ "}";
	}
}

pub fn reprUnion(
	comptime info: std.builtin.Type.Union
) []const u8 {
	comptime {
		var repr: []const u8 = std.fmt.comptimePrint("{s}union{s} {{\n", .{
			switch( info.layout ) {
				.Auto => "",
				.Extern => "extern ",
				.Packed => "packed "
			},
			if( info.tag_type ) |t| 
				switch( @typeInfo(t) ) {
					.Enum => "(enum)",
					else => "(" ++ @typeName(t) ++ ")",
				}
			else
				""
		});

		for( info.fields ) |field| {
			repr = repr ++ std.fmt.comptimePrint("   {s}: {s} align({}),\n", .{
				field.name, @typeName(field.type), field.alignment
			});
		}

		return repr ++ "}";
	}
}
