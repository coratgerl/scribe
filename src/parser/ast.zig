const std = @import("std");
const String = @import("../utils/string.zig").String;

pub const TokenKind = enum {
    Command,
    String,
};

pub const Node = struct {
    kind: TokenKind,
    // If the node is a command, the value is the command name.
    // If the node is a string, the value is the string value.
    value: ?String,
    children: std.ArrayList(Node),

    pub fn init(allocator: std.mem.Allocator, kind: TokenKind, value: ?String) !Node {
        const node = .{
            .kind = kind,
            .value = value,
            .children = std.ArrayList(Node).init(allocator),
        };

        return node;
    }

    // Children are deinit by the parent
    pub fn deinit(self: *Node) void {
        if (self.value) |*value| {
            value.deinit();
        }

        clearChildren(&self.children);
    }

    fn clearChildren(children: *std.ArrayList(Node)) void {
        for (children.items) |*child| {
            if (child.children.items.len > 0) {
                clearChildren(&child.children);
            }

            if (child.value) |*child_value| {
                child_value.deinit();
            }
        }

        children.deinit();
    }

    pub fn addChild(self: *Node, children: *Node) !void {
        try self.children.append(children.*);
    }

    pub fn removeChild(self: *Node, index: usize) void {
        // This operation is O(n) but we need to keep the order of the children
        var node = self.children.orderedRemove(index);

        // We unitialize all the children of the deleted node
        clearChildren(&node.children);
        node.value.?.deinit();
    }
};

pub const Ast = struct {
    root: Node,
    allocator: std.mem.Allocator,
    content: String,

    pub fn init(allocator: std.mem.Allocator, content: String) Ast {
        return Ast{
            .root = try Node.init(
                allocator,
                TokenKind.Command,
                null,
            ),
            .allocator = allocator,
            .content = content,
        };
    }

    pub fn deinit(self: *Ast) void {
        self.content.deinit();
        // Remove all the children of the root
        self.root.deinit();
    }

    // TODO
    pub fn create_tree(self: *Ast) void {
        _ = self;
    }
};

test "Node: Initiliaze a Node" {
    var node = try Node.init(std.testing.allocator, TokenKind.Command, null);
    defer node.deinit();

    try std.testing.expect(node.kind == TokenKind.Command);
    try std.testing.expect(node.value == null);
    try std.testing.expect(node.children.items.len == 0);
}

test "Node: addChild" {
    var node = try Node.init(std.testing.allocator, TokenKind.Command, try String.initDefaultString(std.testing.allocator, "test"));
    defer node.deinit();

    // The child is deinit by the parent
    var child = try Node.init(std.testing.allocator, TokenKind.Command, try String.initDefaultString(std.testing.allocator, "test2"));

    try node.addChild(&child);
    try std.testing.expect(node.children.items.len == 1);
    try std.testing.expect(node.children.items[0].kind == TokenKind.Command);
    try std.testing.expect(node.children.items[0].value.?.compareWithBuffer("test2"));
    try std.testing.expect(node.children.items[0].children.items.len == 0);
}

test "Node: removeChild" {
    var node = try Node.init(std.testing.allocator, TokenKind.Command, null);
    defer node.deinit();

    var child = try Node.init(std.testing.allocator, TokenKind.Command, try String.initDefaultString(std.testing.allocator, "test"));

    var child2 = try Node.init(std.testing.allocator, TokenKind.Command, try String.initDefaultString(std.testing.allocator, "test2"));

    try node.addChild(&child);
    try node.addChild(&child2);

    try std.testing.expect(node.children.items.len == 2);

    node.removeChild(1);
    try std.testing.expect(node.children.items.len == 1);
    try std.testing.expect(node.children.items[0].value.?.compareWithBuffer("test"));
}

test "Ast: Initialize an Ast" {
    const string = try String.initDefaultString(std.testing.allocator, "\\documentclass{article}\\begin{document}\\section{Introduction}\\end{document}");

    var ast = Ast.init(std.testing.allocator, string);
    defer ast.deinit();

    try std.testing.expect(ast.content.compareWithBuffer("\\documentclass{article}\\begin{document}\\section{Introduction}\\end{document}"));
    try std.testing.expect(ast.root.value == null);
    try std.testing.expect(ast.root.children.items.len == 0);
}
