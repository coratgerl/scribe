const std = @import("std");
const String = @import("../utils/string.zig").String;

pub const Node = struct {
    name: String,
    parent: ?*Node,
    children: []Node,
};

pub const Ast = struct {
    root: Node,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, content: *String) !Ast {
        return Ast{
            .root = Node{
                .name = try String.init_with_content(allocator, content),
                .parent = null,
                .children = null,
            },
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Ast) void {
        _ = self;
    }

    pub fn create_tree(self: *Ast) void {
        _ = self;
    }
};

test "Parser: Basic example" {
    var basic_example = try String.init_with_content(std.testing.allocator, "\\begin{document}\\section{Introduction}\\end{document}");
    defer basic_example.deinit();

    var ast = try Ast.init(std.testing.allocator, &basic_example);
    defer ast.deinit();
}
