const std = @import("std");

pub const Token = struct {
    tag: Tag,
    loc: Location,

    pub const Location = struct {
        start: usize,
        end: usize,
    };

    pub const keywords = std.ComptimeStringMap(Tag, .{
        .{ "begin", .begin_command },
        .{ "end", .end_command },
        .{ "textbf", .textbf_command },
        .{ "section", .section_command },
        .{ "usepackage", .usepackage_command },
    });

    pub const Tag = enum {
        root,
        argument,
        string_literal,
        begin_command,
        end_command,
        usepackage_command,
        textbf_command,
        section_command,
        backslash,
        left_brace,
        right_brace,
        left_bracket,
        right_bracket,
        line_break,
        comma,
        eof,
    };
};

pub const Tokenizer = struct {
    source: []const u8,
    index: usize,
    allocator: std.mem.Allocator,

    pub const State = enum {
        start,
        string_literal,
    };

    pub const TokenList = std.MultiArrayList(struct {
        tag: Token.Tag,
        start: usize,
    });

    pub fn init(source: []const u8, allocator: std.mem.Allocator) Tokenizer {
        return Tokenizer{
            .source = source,
            .index = 0,
            .allocator = allocator,
        };
    }

    pub fn tokenize(self: *Tokenizer) !TokenList {
        var tokens = TokenList{};

        // TODO : We will need to estimated the ratio of token in latex
        try tokens.ensureTotalCapacity(self.allocator, self.source.len);

        var i: usize = 0;
        while (true) {
            const token = self.next();

            try tokens.append(self.allocator, .{
                .tag = token.tag,
                .start = token.loc.start,
            });

            if (token.tag == .eof)
                break;

            i += 1;
        }

        return tokens;
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
                    '[' => {
                        result.tag = .left_bracket;
                        result.loc.start = self.index;
                        result.loc.end = self.index;

                        self.index += 1;

                        break;
                    },
                    ']' => {
                        result.tag = .right_bracket;
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
                    ',' => {
                        result.tag = .comma;
                        result.loc.start = self.index;
                        result.loc.end = self.index;

                        self.index += 1;
                        break;
                    },
                    'a'...'z', 'A'...'Z', ' ' => {
                        result.tag = .string_literal;
                        state = .string_literal;
                    },
                    '\n' => {},
                    else => {},
                },
                .string_literal => switch (c) {
                    'a'...'z', 'A'...'Z', ' ' => {},
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

test "Tokenizer: begin document" {
    try testTokenize("\\begin{document}\\textbf{Hello}This is a valid content\\end{document}", &.{
        .backslash,
        .begin_command,
        .left_brace,
        .string_literal,
        .right_brace,
        .backslash,
        .textbf_command,
        .left_brace,
        .string_literal,
        .right_brace,
        .string_literal,
        .backslash,
        .end_command,
        .left_brace,
        .string_literal,
        .right_brace,
        .eof,
    });
}

test "Tokenizer: command with multiple arguments" {
    try testTokenize("\\textbf{argument1, argument2}", &.{
        .backslash,
        .textbf_command,
        .left_brace,
        .string_literal,
        .comma,
        .string_literal,
        .right_brace,
        .eof,
    });

    try testTokenize("\\usepackage[utf8]{inputenc}", &.{
        .backslash,
        .usepackage_command,
        .left_bracket,
        .string_literal,
        .right_bracket,
        .left_brace,
        .string_literal,
        .right_brace,
        .eof,
    });
}

test "Tokenizer: simple textbf" {
    try testTokenize("\\textbf{Hello}", &.{
        .backslash,
        .textbf_command,
        .left_brace,
        .string_literal,
        .right_brace,
        .eof,
    });
}

test "Tokenizer: recursive textbf" {
    try testTokenize("\\textbf{\\textbf{Hello}}", &.{
        .backslash,
        .textbf_command,
        .left_brace,
        .backslash,
        .textbf_command,
        .left_brace,
        .string_literal,
        .right_brace,
        .right_brace,
        .eof,
    });
}

test "Tokenizer: begin" {
    try testTokenize("\\begin{document}", &.{
        .backslash,
        .begin_command,
        .left_brace,
        .string_literal,
        .right_brace,
        .eof,
    });
}

test "Tokenizer: test with content in section and line break" {
    try testTokenize("\\begin{document}\n\\section{Introduction}\nContent of the introduction\n\\end{document}", &.{
        .backslash,
        .begin_command,
        .left_brace,
        .string_literal,
        .right_brace,
        .backslash,
        .section_command,
        .left_brace,
        .string_literal,
        .right_brace,
        .string_literal,
        .backslash,
        .end_command,
        .left_brace,
        .string_literal,
        .right_brace,
        .eof,
    });
}

// TODO: Create test for this use case \textbf{textbf}

fn testTokenize(source: [:0]const u8, expected_token_tags: []const Token.Tag) !void {
    var tokenizer = Tokenizer.init(source, std.testing.allocator);
    var tokens = try tokenizer.tokenize();
    defer tokens.deinit(std.testing.allocator);

    var i: usize = 0;
    for (expected_token_tags) |expected_token_tag| {
        try std.testing.expectEqual(expected_token_tag, tokens.get(i).tag);

        i += 1;
    }
}
