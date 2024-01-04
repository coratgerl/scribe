const std = @import("std");
const String = @import("../utils/string.zig").String;
const Node = @import("./ast.zig").Node;
const TokenKind = @import("./ast.zig").TokenKind;

pub const Parser = struct {
    allocator: std.mem.Allocator,
    content: *String,
    root: *Node,

    pub fn init(allocator: std.mem.Allocator, content: *String, root: *Node) Parser {
        return .{
            .allocator = allocator,
            .content = content,
            .root = root,
        };
    }

    pub fn deinit(self: *Parser) void {
        _ = self;
    }

    pub fn parseCommand(self: *Parser, index_of_command: usize, node: *Node) !usize {
        var i: usize = index_of_command;

        var previous_command_node = node;

        // 1. Initialize a previous node that equal to root node
        // 2. Add the command to the previous node (root or child node)
        // 3. Previous node equal to child mode

        // We through to all the content but we will break earlier when the command is finished
        // Here typically we can use while(true) but for more secure we only trough the content
        while (i < self.content.size) {
            const character = self.content.buffer.?[i];

            if (character == '\\') {
                var command_name = try self.getCommandName(i + 1);

                var child_node = try Node.init(self.allocator, TokenKind.Command, null, false);
                child_node.addValue(&command_name);

                try previous_command_node.addChild(&child_node);

                std.debug.print("Command name : {s}\n", .{command_name.toString()});
                std.debug.print("Is root node : {any}\n", .{previous_command_node.isRootg});

                previous_command_node = &child_node;

                // i += command_name.len();
            }

            i += 1;
        }

        return 0;
    }

    fn getCommandName(self: *Parser, index_of_command: usize) !String {
        var i: usize = index_of_command;

        var string = String.init(self.allocator);

        while (i < self.content.size) {
            const character = self.content.buffer.?[i];

            if (character == '{') {
                break;
            }

            try string.concatCharacter(character);

            i += 1;
        }

        return string;
    }

    // Si je rencontre un \
    // Je crée un node de type commande
    // Je récupère le nom de la commande
    // J'ajoute le nom dans la value du node
    // J'ajoute le node dans children
    // J'appelle la fonction récursive avec en paramètre le children et l'index du \ + 1
    // La fonction récupère tous les subnodes et les ajoute dans le node
    // La fonction retourne l'index de la fin de la commande
    // La fonction parse refresh l'index et continue
    // La fonction parse ne doit jamais parcourir un enfant

    pub fn parse(self: *Parser) void {
        var i: usize = 0;

        while (i < self.content.size) {
            const c = self.content.buffer.?[i];

            if (c == '\\') {
                var node = Node.init(self.allocator, Node.Kind.Command);
                // Memory leak
                self.root.addChild(&node);

                self.parseCommand(i + 1, &node);
            }

            i += 1;
        }
    }
};

test "Parser: parseCommand" {
    // \documentclass{article}
    // \begin{document}
    // \section{Introduction}
    // This is a simple document.
    // \end{document}

    var string = try String.initDefaultString(std.testing.allocator, "\\textbf{\\textbf{Hello}}");
    defer string.deinit();

    var root_node = try Node.init(std.testing.allocator, TokenKind.Command, null, true);
    defer root_node.deinit();

    var parser = Parser.init(std.testing.allocator, &string, &root_node);

    _ = try parser.parseCommand(0, &root_node);

    if (root_node.children.items[0].value) |value| {
        std.debug.print("Node value : {s}\n", .{value.toString()});

        // if (root_node.children.items[0].children.items[0].value) |value2| {
        //     std.debug.print("Sub node value : {s}\n", .{value2.toString()});
        // }
    }
}

test "Parser: getCommandName" {
    var string = try String.initDefaultString(std.testing.allocator, "\\begin{document}");
    defer string.deinit();

    var node = try Node.init(std.testing.allocator, TokenKind.Command, null, true);
    defer node.deinit();

    var parser = Parser.init(std.testing.allocator, &string, &node);
    var command_name = try parser.getCommandName(1);
    defer command_name.deinit();

    try std.testing.expect(command_name.compareWithBuffer("begin"));

    var command_name_not_exist = try parser.getCommandName(100);
    defer command_name_not_exist.deinit();

    try std.testing.expect(command_name_not_exist.isEmpty());
}
