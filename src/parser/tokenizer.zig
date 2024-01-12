const std = @import("std");

pub const Token = struct {
    tag: Tag,
    loc: Location,

    pub const Location = struct {
        start: usize,
        end: usize,
    };

    pub const keywords = std.ComptimeStringMap(Tag, .{
        .{ "title", .title_function },
        .{ "bold", .bold_function },
        .{ "figure", .figure_function },
        .{ "image", .image_function },
        .{ "caption", .caption_function },
        .{ "equation", .equation_function },
        .{ "list", .list_function },
    });

    pub const Tag = enum {
        root,
        title_function,
        bold_function,
        figure_function,
        image_function,
        caption_function,
        equation_function,
        list_function,
        string_argument,
        number_argument,
        string_literal,
        line_break,
        comma,
        left_parenthesis,
        right_parenthesis,
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
                    ' ' => {
                        result.loc.start = self.index + 1;
                    },
                    '(' => {
                        result.tag = .left_parenthesis;
                        result.loc.start = self.index;
                        result.loc.end = self.index;

                        self.index += 1;

                        break;
                    },
                    ')' => {
                        result.tag = .right_parenthesis;
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
                    'a'...'z', 'A'...'Z', '0'...'9' => {
                        result.tag = .string_literal;
                        state = .string_literal;
                    },
                    '\n' => {
                        result.tag = .line_break;
                        result.loc.start = self.index;
                        result.loc.end = self.index;

                        self.index += 1;
                        break;
                    },
                    else => {},
                },
                .string_literal => switch (c) {
                    'a'...'z', 'A'...'Z', ' ', '0'...'9', '.', '?', '!' => {},
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

test "Tokenizer: title" {
    try testTokenize("title(1, Introduction)", &.{
        .title_function,
        .left_parenthesis,
        .string_literal,
        .comma,
        .string_literal,
        .right_parenthesis,
        .eof,
    });
}

test "Tokenizer: title with number" {
    try testTokenize("title(1, Introduction 1)", &.{
        .title_function,
        .left_parenthesis,
        .string_literal,
        .comma,
        .string_literal,
        .right_parenthesis,
        .eof,
    });

    try testTokenize("title(1, 1. Introduction)", &.{
        .title_function,
        .left_parenthesis,
        .string_literal,
        .comma,
        .string_literal,
        .right_parenthesis,
        .eof,
    });
}

test "Tokenizer: bold" {
    try testTokenize("bold(Introduction)", &.{
        .bold_function,
        .left_parenthesis,
        .string_literal,
        .right_parenthesis,
        .eof,
    });
}

test "Tokenizer: list" {
    try testTokenize("list(elem1, elem2)", &.{
        .list_function,
        .left_parenthesis,
        .string_literal,
        .comma,
        .string_literal,
        .right_parenthesis,
        .eof,
    });
}

test "Tokenizer: caption" {
    try testTokenize("caption(caption text)", &.{
        .caption_function,
        .left_parenthesis,
        .string_literal,
        .right_parenthesis,
        .eof,
    });
}

test "Tokenizer: image" {
    try testTokenize("image(test.png,100)", &.{
        .image_function,
        .left_parenthesis,
        .string_literal,
        .comma,
        .string_literal,
        .right_parenthesis,
        .eof,
    });
}

test "Tokenizer: figure" {
    try testTokenize("figure(image(image.png, 80), caption(This is a caption))", &.{
        .figure_function,
        .left_parenthesis,
        .image_function,
        .left_parenthesis,
        .string_literal,
        .comma,
        .string_literal,
        .right_parenthesis,
        .comma,
        .caption_function,
        .left_parenthesis,
        .string_literal,
        .right_parenthesis,
        .right_parenthesis,
        .eof,
    });
}

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
