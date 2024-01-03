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

    fn parseCommand(self: *Parser, index_of_command: usize, node: *Node) usize {
        _ = node;
        var i: usize = index_of_command;

        // We through to all the content but we will break earlier when the command is finished
        // Here typically we can use while(true) but for more secure we only trough the content
        while (i < self.content.size) {
            const character = self.content.buffer.?[i];
            _ = character;

            i += 1;
        }

        return 0;
    }

    fn getCommandName(self: *Parser, index_of_command: usize) !String {
        var i: usize = index_of_command;

        var string = String.init(self.allocator);

        var first_bracket_encountered = false;

        while (i < self.content.size) {
            const character = self.content.buffer.?[i];

            if (character == '{') {
                first_bracket_encountered = true;
                i += 1;
                continue;
            }

            if (character == '}' and first_bracket_encountered) {
                break;
            }

            if (first_bracket_encountered) {
                try string.concatCharacter(character);
            }

            i += 1;
        }

        if (!first_bracket_encountered)
            unreachable;

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
                self.root.addChild(&node);

                self.parseCommand(i + 1, &node);
            }

            i += 1;
        }
    }
};

test "Parser: parse (Basic example)" {
    // \documentclass{article}
    // \begin{document}
    // \section{Introduction}
    // This is a simple document.
    // \end{document}
}

test "Parser: getCommandName" {
    var string = try String.initDefaultString(std.testing.allocator, "\\begin{document}");
    defer string.deinit();

    var node = try Node.init(std.testing.allocator, TokenKind.Command, null);

    var parser = Parser.init(std.testing.allocator, &string, &node);
    var command_name = try parser.getCommandName(1);
    defer command_name.deinit();

    try std.testing.expect(command_name.compareWithBuffer("document"));
}