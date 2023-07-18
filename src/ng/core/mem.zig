const std = @import("std");



pub fn interleave(
    dest: []u8,
    sources: anytype
) void {
    var stride: usize = 0;
    var total_bytes: usize = 0;
    var length: usize = sources[0].len;

    inline for( sources ) |src| {
        const T = @TypeOf(src);
        stride += @sizeOf(std.meta.Child(T));
        total_bytes += @sizeOf(std.meta.Child(T)) * src.len;

        if( src.len != length )
            @panic("One of the sources doenst have the same length as the first one.");
    }

    if( dest.len != total_bytes ) 
        @panic("Destination doesnt have the same size as all combined sources.");

    var position: usize = 0;

    for( 0..length ) |idx| {
        inline for( sources ) |src| {
            const bytes = std.mem.toBytes(src[idx]);
            @memcpy(dest[position..position+bytes.len], &bytes);
            position += bytes.len;
        }
    }
}

pub fn interleaveSize(
    sources: anytype
) usize {
    var total_bytes: usize = 0;

    inline for( sources ) |src| {
        const T = @TypeOf(src);
        total_bytes += @sizeOf(std.meta.Child(T)) * src.len;
    }

    return total_bytes;
}
