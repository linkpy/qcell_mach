const std = @import("std");

const Allocator = std.mem.Allocator;



pub fn Queue(
	comptime T: type
) type {
	return struct {
		const QueueT = @This();
		const NodeArray = std.ArrayListUnmanaged(Node);

		const Node = struct {
			next: ?u32,
			prev: ?u32,
			data: T,
			used: bool,
		};

		first: ?u32 = null,
		last: ?u32 = null,

		nodes: NodeArray = .{},
		unused_nodes: u32 = 0,



		pub fn initCapacity(
			alloc: Allocator,
			node_count: u32
		) Allocator.Error!QueueT {
			return QueueT {
				.nodes = try NodeArray.initCapacity(alloc, node_count),
				.unused_nodes = 0,
			};
		}

		pub fn deinit(
			self: *QueueT,
			alloc: Allocator,
		) void {
			self.nodes.deinit(alloc);
		}



		pub fn push(
			self: *QueueT,
			alloc: Allocator,
			data: T
		) Allocator.Error!void {
			var nidx: u32 = 0;
			var node: *Node = undefined;

			if( self.unused_nodes > 0 ) {
				nidx = self.findUnusedNode().?;
				node = self.getNode(nidx);

				node.used = true;
				node.data = data;
				self.unused_nodes -= 1;
			} else {
				nidx = @intCast(self.nodes.items.len);
				try self.nodes.append(alloc, .{
					.next = null,
					.prev = null,
					.data = data,
					.used = true,
				});
				node = self.getNode(nidx);
			}

			if( self.last ) |last_idx| {
				var last = self.getNode(last_idx);
				last.next = nidx;
				node.prev = last_idx;
			} else {
				self.first = nidx;
			}

			self.last = nidx;
		}

		pub fn pop(
			self: *QueueT,
		) ?T {
			if( self.first ) |first_idx| {
				var node = self.getNode(first_idx);
				
				if( node.next ) |next_idx| {
					var next = self.getNode(next_idx);
					next.prev = null;
					self.first = next_idx;
				} else {
					self.first = null;
					self.last = null;
				}

				node.next = null;
				node.used = false;
				self.unused_nodes += 1;
				return node.data;
			}

			return null;
		}

		pub fn isEmpty(
			self: QueueT
		) bool {
			return self.first == null;
		}



		fn findUnusedNode(
			self: QueueT
		) ?u32 {
			for( self.nodes.items, 0.. ) |n, i| {
				if( !n.used )
					return @intCast(i);
			}

			return null;
		}

		inline fn getNode(
			self: *QueueT,
			idx: u32
		) *Node {
			return &self.nodes.items[idx];
		}
	};
}
