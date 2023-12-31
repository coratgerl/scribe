const std = @import("std");
const String = @import("../utils/string.zig").String;

pub const TokenKind = enum {
    Command,
    String,
};

pub const Token = struct { kind: TokenKind, value: String };

pub const Lexer = struct {
    tokens: std.DoublyLinkedList(Token),
    content: String,

    pub fn init(content: String) Lexer {
        return .{
            .tokens = std.DoublyLinkedList(Token){},
            .content = content,
        };
    }

    pub fn evaluate(self: *Lexer) void {
        var i: usize = 0;

        while (i < self.content.size) {
            const character = self.content.buffer.?[i];
            _ = character;

            var token_node = std.DoublyLinkedList(Token).Node{ .data = Token{ .kind = TokenKind.Command, .value = String.init(std.testing.allocator) } };

            self.tokens.append(&token_node);

            i += 1;
        }
    }
};

test "Lexer - Evaluate : Basic example" {
    var string_content = try String.initDefaultString(std.testing.allocator, "\\begin{document}\\section{Introduction}\\end{document}");
    defer string_content.deinit();

    var lexer = Lexer.init(string_content);
    lexer.evaluate();
}
