const std = @import("std");
const String = @import("../utils/string.zig").String;

pub const Parser = struct {
    content: *String,
    allocator: std.mem.Allocator,

    pub fn init(content: *String, allocator: std.mem.Allocator) Parser {
        return .{
            .content = content.*,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Parser) void {
        _ = self;
    }
};
