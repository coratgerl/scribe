const std = @import("std");

const tests = struct {
    pub usingnamespace @import("utils/string.zig");
    pub usingnamespace @import("parser/ast.zig");
};

test {
    std.testing.log_level = std.log.Level.err;
    std.testing.refAllDecls(tests);
}
