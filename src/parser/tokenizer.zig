const std = @import("std");

pub const Token = struct {
    tag: Tag,
    loc: Location,

    pub const Location = struct {
        start: usize,
        end: usize,
    };

    pub const keywords = std.ComptimeStringMap(Tag, .{
        .{ "begin", .command_begin },
        .{ "textbf", .command_textbf },
    });

    pub const Tag = enum {
        string_literal,
        command_begin,
        command_textbf,
        backslash,
        left_brace,
        right_brace,
        eof,
    };
};

pub const Tokenizer = struct {
    source: []const u8,
    index: usize,

    pub const State = enum {
        start,
        string_literal,
    };

    pub fn init(source: []const u8) Tokenizer {
        return Tokenizer{
            .source = source,
            .index = 0,
        };
    }

    pub fn next(self: *Tokenizer) Token {
        var result = Token{
            .tag = .eof,
            .loc = .{
                .start = self.index,
                .end = undefined,
            },
        };

        var state: State = .start;

        while (self.index < self.source.len) : (self.index += 1) {
            const c = self.source[self.index];

            switch (state) {
                .start => switch (c) {
                    '\\' => {
                        result.tag = .backslash;
                        result.loc.start = self.index;
                        result.loc.end = self.index;

                        self.index += 1;

                        break;
                    },
                    '{' => {
                        result.tag = .left_brace;
                        result.loc.start = self.index;
                        result.loc.end = self.index;

                        self.index += 1;
                        break;
                    },
                    '}' => {
                        result.tag = .right_brace;
                        result.loc.start = self.index;
                        result.loc.end = self.index;

                        self.index += 1;

                        break;
                    },
                    'a'...'z', 'A'...'Z' => {
                        result.tag = .string_literal;
                        state = .string_literal;
                    },
                    else => {},
                },
                .string_literal => switch (c) {
                    'a'...'z', 'A'...'Z' => {},
                    else => {
                        if (Token.keywords.get(self.source[result.loc.start..self.index])) |tag| {
                            result.tag = tag;
                        } else {
                            result.tag = .string_literal;
                        }

                        break;
                    },
                },
            }
        }

        result.loc.end = self.index;

        return result;
    }
};

test "Tokenizer: simple textbf" {
    try testTokenize("\\textbf{Hello}", &.{
        .backslash,
        .command_textbf,
        .left_brace,
        .string_literal,
        .right_brace,
        .eof,
    });
}

test "Tokenizer: recursive textbf" {
    try testTokenize("\\textbf{\\textbf{Hello}}", &.{
        .backslash,
        .command_textbf,
        .left_brace,
        .backslash,
        .command_textbf,
        .left_brace,
        .string_literal,
        .right_brace,
        .right_brace,
        .eof,
    });
}

fn testTokenize(source: [:0]const u8, expected_token_tags: []const Token.Tag) !void {
    var tokenizer = Tokenizer.init(source);
    for (expected_token_tags) |expected_token_tag| {
        const token = tokenizer.next();
        std.debug.print("token: {any}\n", .{token.tag});
        try std.testing.expectEqual(expected_token_tag, token.tag);
    }
}
