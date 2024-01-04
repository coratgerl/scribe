const std = @import("std");
const String = @import("../utils/string.zig").String;

pub const TokenKind = enum {
    Command,
    String,
};

pub const Node = struct {
    kind: TokenKind,
    isRoot: bool,
    // If the node is a command, the value is the command name.
    // If the node is a string, the value is the string value.
    value: *String,
    children: std.ArrayList(*Node),

    pub fn init(allocator: std.mem.Allocator, kind: TokenKind, value: *String, isRoot: bool) !Node {
        return .{
            .kind = kind,
            .value = value,
            .children = std.ArrayList(*Node).init(allocator),
            .isRoot = isRoot,
        };
    }

    // Children are deinit by the parent
    pub fn deinit(self: *Node) void {
        self.value.deinit();

        clearChildren(&self.children);
    }

    fn clearChildren(children: *std.ArrayList(*Node)) void {
        for (children.items) |*child| {
            if (child.*.children.items.len > 0) {
                clearChildren(&child.*.children);
            }

            child.*.value.deinit();
        }

        children.deinit();
        children.clearRetainingCapacity();
    }

    pub fn addChild(self: *Node, children: *Node) !void {
        try self.children.append(children);
    }

    pub fn removeChild(self: *Node, index: usize) void {
        // This operation is O(n) but we need to keep the order of the children
        var node = self.children.orderedRemove(index);

        // We unitialize all the children of the deleted node
        clearChildren(&node.children);
        node.value.deinit();
    }
};

pub const Ast = struct {
    root: Node,
    allocator: std.mem.Allocator,
    content: String,

    pub fn init(allocator: std.mem.Allocator, content: String) !Ast {
        var value_root_node = try String.initDefaultString(allocator, "root");
        const node = try Node.init(allocator, TokenKind.Command, &value_root_node, true);

        return .{
            .root = node,
            .allocator = allocator,
            .content = content,
        };
    }

    pub fn deinit(self: *Ast) void {
        self.root.deinit();
        self.content.deinit();
    }

    // TODO
    pub fn create_tree(self: *Ast) void {
        _ = self;
    }
};

test "Node: Initiliaze a Node" {
    var root_node_content = try String.initDefaultString(std.testing.allocator, "Root node");

    var node = try Node.init(std.testing.allocator, TokenKind.Command, &root_node_content, true);
    defer node.deinit();

    try std.testing.expect(node.kind == TokenKind.Command);
    try std.testing.expect(node.value.compareWithBuffer("Root node"));
    try std.testing.expect(node.children.items.len == 0);
}

test "Node: Initialize a Node with children and sub children" {
    var root_node_content = try String.initDefaultString(std.testing.allocator, "Root node");
    var child_node_content = try String.initDefaultString(std.testing.allocator, "Child node");
    var sub_child_node_content = try String.initDefaultString(std.testing.allocator, "Sub child node");

    var node = try Node.init(std.testing.allocator, TokenKind.Command, &root_node_content, true);
    defer node.deinit();

    var child = try Node.init(std.testing.allocator, TokenKind.Command, &child_node_content, false);
    var sub_child = try Node.init(std.testing.allocator, TokenKind.Command, &sub_child_node_content, false);

    try child.addChild(&sub_child);
    try node.addChild(&child);

    try std.testing.expect(node.children.items.len == 1);
    try std.testing.expect(node.children.items[0].children.items.len == 1);
    try std.testing.expect(node.children.items[0].children.items[0].value.compareWithBuffer("Sub child node"));
}

test "Node: clearChildren" {
    var root_node_content = try String.initDefaultString(std.testing.allocator, "Root node");
    var child_node_content = try String.initDefaultString(std.testing.allocator, "Child node");
    var sub_child_node_content = try String.initDefaultString(std.testing.allocator, "Sub child node");

    var node = try Node.init(std.testing.allocator, TokenKind.Command, &root_node_content, true);

    var child = try Node.init(std.testing.allocator, TokenKind.Command, &child_node_content, false);
    var sub_child = try Node.init(std.testing.allocator, TokenKind.Command, &sub_child_node_content, false);

    try child.addChild(&sub_child);
    try node.addChild(&child);

    node.deinit();

    try std.testing.expect(node.children.items.len == 0);
    try std.testing.expect(node.value.size == 0);
}

test "Node: addChild" {
    var root_node_content = try String.initDefaultString(std.testing.allocator, "Root node");
    var child_node_content = try String.initDefaultString(std.testing.allocator, "Child node");

    var node = try Node.init(std.testing.allocator, TokenKind.Command, &root_node_content, true);
    defer node.deinit();

    // The child is deinit by the parent
    var child = try Node.init(std.testing.allocator, TokenKind.Command, &child_node_content, false);

    try node.addChild(&child);
    try std.testing.expect(node.children.items.len == 1);
    try std.testing.expect(node.children.items[0].kind == TokenKind.Command);
    try std.testing.expect(node.children.items[0].value.compareWithBuffer("Child node"));
    try std.testing.expect(node.children.items[0].children.items.len == 0);
}

test "Node: removeChild" {
    var root_node_content = try String.initDefaultString(std.testing.allocator, "Root node");
    var child_node_content = try String.initDefaultString(std.testing.allocator, "Child node");
    var sub_child_node_content = try String.initDefaultString(std.testing.allocator, "Sub child node");

    var node = try Node.init(std.testing.allocator, TokenKind.Command, &root_node_content, true);
    defer node.deinit();

    var child = try Node.init(std.testing.allocator, TokenKind.Command, &sub_child_node_content, false);
    var child2 = try Node.init(std.testing.allocator, TokenKind.Command, &child_node_content, false);

    try node.addChild(&child);
    try node.addChild(&child2);

    try std.testing.expect(node.children.items.len == 2);

    node.removeChild(1);
    try std.testing.expect(node.children.items.len == 1);
    try std.testing.expect(node.children.items[0].value.compareWithBuffer("Sub child node"));
}

test "Ast: Initialize an Ast" {
    const content = try String.initDefaultString(std.testing.allocator, "\\documentclass{article}\\begin{document}\\section{Introduction}\\end{document}");

    var ast = try Ast.init(std.testing.allocator, content);
    defer ast.deinit();

    try std.testing.expect(ast.content.compareWithBuffer("\\documentclass{article}\\begin{document}\\section{Introduction}\\end{document}"));
    try std.testing.expect(ast.root.value.compareWithBuffer("root"));
    try std.testing.expect(ast.root.children.items.len == 0);
}
