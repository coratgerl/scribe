const std = @import("std");
const String = @import("../utils/string.zig").String;

pub const TokenKind = enum {
    Command,
    String,
};

pub const Token = struct { kind: TokenKind, value: String };

pub const Lexer = struct {
    tokens: std.ArrayList(Token),
    content: String,
    allocator: std.mem.Allocator,

    pub fn init(content: String, allocator: std.mem.Allocator) Lexer {
        const tokens = std.ArrayList(Token).initCapacity(allocator, content.size) catch unreachable;

        return .{
            .allocator = allocator,
            .tokens = tokens,
            .content = content,
        };
    }

    pub fn deinit(self: *Lexer) void {
        for (self.tokens.items) |*token| {
            token.value.deinit();
        }

        self.tokens.deinit();
        self.content.deinit();
    }

    fn addStringToToken(self: *Lexer, string: *String) !void {
        try self.tokens.append(.{
            .kind = TokenKind.String,
            .value = try String.initDefaultString(self.allocator, string.*.toString()),
        });
        try string.clear();
    }

    pub fn evaluate(self: *Lexer) !void {
        var i: usize = 0;

        var string_character = String.init(self.allocator);
        defer string_character.deinit();

        var is_command_encountered = false;
        var is_first_bracket_encountered = false;

        while (i < self.content.size) {
            const character = self.content.buffer.?[i];

            if (character == '\\') {
                try string_character.concatCharacter(character);

                is_command_encountered = true;
            } else if (is_command_encountered and character == '{') {
                // We add the command to the tokens list
                try self.addStringToToken(&string_character);

                try string_character.concatCharacter(character);

                // We add the { to the tokens list
                try self.addStringToToken(&string_character);

                is_first_bracket_encountered = true;
                is_command_encountered = false;
            } else if (is_first_bracket_encountered and character == '}') {
                // We add the content of the command in the tokens list
                try self.addStringToToken(&string_character);

                try string_character.concatCharacter(character);

                // We add the } to the tokens list
                try self.addStringToToken(&string_character);

                is_first_bracket_encountered = false;
            } else {
                try string_character.concatCharacter(character);
            }

            i += 1;
        }
    }
};

test "Lexer - Evaluate : Basic example" {
    const string_content = try String.initDefaultString(std.testing.allocator, "\\begin{document}\\section{Introduction}\\end{document}");

    // ['\begin', '{', 'document', '}', '\section', '{', 'Introduction', '}', '\end', '{', 'document', '}']

    var lexer = Lexer.init(string_content, std.testing.allocator);
    defer lexer.deinit();

    try lexer.evaluate();

    try std.testing.expect(lexer.tokens.items.len == 12);
    try std.testing.expect(lexer.tokens.items[0].value.compareWithBuffer("\\begin"));
    try std.testing.expect(lexer.tokens.items[1].value.compareWithBuffer("{"));
    try std.testing.expect(lexer.tokens.items[2].value.compareWithBuffer("document"));
    try std.testing.expect(lexer.tokens.items[3].value.compareWithBuffer("}"));
    try std.testing.expect(lexer.tokens.items[4].value.compareWithBuffer("\\section"));
    try std.testing.expect(lexer.tokens.items[5].value.compareWithBuffer("{"));
    try std.testing.expect(lexer.tokens.items[6].value.compareWithBuffer("Introduction"));
    try std.testing.expect(lexer.tokens.items[7].value.compareWithBuffer("}"));
    try std.testing.expect(lexer.tokens.items[8].value.compareWithBuffer("\\end"));
    try std.testing.expect(lexer.tokens.items[9].value.compareWithBuffer("{"));
    try std.testing.expect(lexer.tokens.items[10].value.compareWithBuffer("document"));
    try std.testing.expect(lexer.tokens.items[11].value.compareWithBuffer("}"));
}

test "Lexer - Evaluate : Basic example 2" {
    const string_content = try String.initDefaultString(std.testing.allocator, "\\begin{document}\\section{Introduction}This is a content text\\end{document}");

    // ['\begin', '{', 'document', '}', '\section', '{', 'Introduction', '}', 'This is a content text', '\end', '{', 'document', '}']

    var lexer = Lexer.init(string_content, std.testing.allocator);
    defer lexer.deinit();

    try lexer.evaluate();

    // try std.testing.expect(lexer.tokens.items.len == 12);
    // try std.testing.expect(lexer.tokens.items[0].value.compareWithBuffer("\\begin"));
    // try std.testing.expect(lexer.tokens.items[1].value.compareWithBuffer("{"));
    // try std.testing.expect(lexer.tokens.items[2].value.compareWithBuffer("document"));
    // try std.testing.expect(lexer.tokens.items[3].value.compareWithBuffer("}"));
    // try std.testing.expect(lexer.tokens.items[4].value.compareWithBuffer("\\section"));
    // try std.testing.expect(lexer.tokens.items[5].value.compareWithBuffer("{"));
    // try std.testing.expect(lexer.tokens.items[6].value.compareWithBuffer("Introduction"));
    // try std.testing.expect(lexer.tokens.items[7].value.compareWithBuffer("}"));
    // try std.testing.expect(lexer.tokens.items[8].value.compareWithBuffer("\\end"));
    // try std.testing.expect(lexer.tokens.items[9].value.compareWithBuffer("{"));
    // try std.testing.expect(lexer.tokens.items[10].value.compareWithBuffer("document"));
    // try std.testing.expect(lexer.tokens.items[11].value.compareWithBuffer("}"));

    for (lexer.tokens.items) |*token| {
        std.debug.print("Token: {s}\n", .{token.value.toString()});
    }
}
