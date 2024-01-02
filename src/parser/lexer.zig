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

    pub fn init(content: String) Lexer {
        var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const mem_allocator = arena_allocator.allocator();

        const tokens = std.ArrayList(Token).initCapacity(mem_allocator, content.size) catch unreachable;

        return .{
            .allocator = mem_allocator,
            .tokens = tokens,
            .content = content,
        };
    }

    pub fn deinit(self: *Lexer) void {
        var i: usize = 0;

        while (i < self.tokens.items.len) {
            self.tokens.items[i].value.deinit();
            i += 1;
        }

        defer self.tokens.deinit();
    }

    pub fn evaluate(self: *Lexer) !void {
        var i: usize = 0;

        var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var string_character = String.init(arena_allocator.allocator());

        var is_command_encountered = false;
        // _ = is_command_encountered;
        // var is_first_bracket_encountered = false;
        // _ = is_first_bracket_encountered;

        while (i < self.content.size) {
            const character = self.content.buffer.?[i];

            if (character == '\\') {
                is_command_encountered = true;
                try string_character.concatCharacter(character);
            } else if (is_command_encountered and character == '{') {
                // We add the command to the tokens list
                const string_clone = try string_character.clone();

                try self.tokens.append(.{ .kind = TokenKind.Command, .value = string_clone });

                try string_character.clear();
                try string_character.concatCharacter(character);

                // We add the { to the tokens list
                // try self.tokens.append(.{ .kind = TokenKind.Command, .value = string_character });

                // try string_character.clear();

                // is_command_encountered = false;
            }

            // if (character == '\\') {
            //     is_command_encountered = true;
            //     try string_character.concatCharacter(character);
            // } else if (is_command_encountered and character == '{') {
            //     // We add the command to the tokens list
            //     try self.tokens.append(.{ .kind = TokenKind.Command, .value = string_character });

            //     try string_character.clear();
            //     try string_character.concatCharacter(character);

            //     // We add the { to the tokens list
            //     try self.tokens.append(.{ .kind = TokenKind.Command, .value = string_character });

            //     try string_character.clear();

            //     is_command_encountered = false;
            //     is_first_bracket_encountered = true;
            // } else if (is_first_bracket_encountered and character == '}') {
            //     // We add the command to the tokens list
            //     try self.tokens.append(.{ .kind = TokenKind.Command, .value = string_character });

            //     try string_character.clear();
            //     try string_character.concatCharacter(character);

            //     // We add the } to the tokens list
            //     try self.tokens.append(.{ .kind = TokenKind.Command, .value = string_character });

            //     try string_character.clear();

            //     is_first_bracket_encountered = false;
            // } else {
            //     try string_character.concatCharacter(character);
            // }

            i += 1;
        }
    }
};

test "Lexer - Evaluate : Basic example" {
    var string_content = try String.initDefaultString(std.testing.allocator, "\\begin{document}\\section{Introduction}\\end{document}");
    defer string_content.deinit();

    // ['\begin', '{', 'document', '}', '\section', '{', 'Introduction', '}', '\end', '{', 'document', '}']

    var lexer = Lexer.init(string_content);
    defer lexer.deinit();

    try lexer.evaluate();

    var i: usize = 0;

    std.debug.print("Size : {d}\n", .{lexer.tokens.items.len});

    while (i < lexer.tokens.items.len) {
        const token = lexer.tokens.items[i];

        std.debug.print("{s}\n", .{token.value.toString()});

        i += 1;
    }
}
