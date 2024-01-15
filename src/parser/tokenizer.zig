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
        space,
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
        backslash,
        string_literal,
    };

    pub const TokenList = std.MultiArrayList(struct {
        tag: Token.Tag,
        loc: Token.Location,
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
                .loc = token.loc,
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
                        result.tag = .space;
                        result.loc.start = self.index;
                        result.loc.end = self.index;

                        self.index += 1;

                        break;
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
                    'a'...'z', 'A'...'Z', '0'...'9', '.', '?', '!' => {
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
                    '\\' => {
                        // \\ permit to ignore the next command for example : caption(\caption text)
                        result.tag = .string_literal;
                        result.loc.start += 1;

                        state = .backslash;
                    },
                    else => {},
                },
                .backslash => switch (c) {
                    'a'...'z', 'A'...'Z', '0'...'9', '.', '?', '!' => {},
                    else => {
                        result.tag = .string_literal;
                        break;
                    },
                },
                .string_literal => switch (c) {
                    'a'...'z', 'A'...'Z', '0'...'9', '.', '?', '!' => {},
                    else => {
                        if (Token.keywords.get(self.source[result.loc.start..self.index])) |tag| {
                            result.tag = tag;
                        }

                        break;
                    },
                },
            }
        }

        result.loc.end = self.index - 1;

        return result;
    }
};

test "Tokenizer: title" {
    try testTokenize("title(1, Introduction)", &.{
        .title_function,
        .left_parenthesis,
        .string_literal,
        .comma,
        .space,
        .string_literal,
        .right_parenthesis,
        .eof,
    }, &.{
        .{ .start = 0, .end = 4 },
        .{ .start = 5, .end = 5 },
        .{ .start = 6, .end = 6 },
        .{ .start = 7, .end = 7 },
        .{ .start = 8, .end = 8 },
        .{ .start = 9, .end = 20 },
        .{ .start = 21, .end = 21 },
    });

    try testTokenize("title(1,Introduction)", &.{
        .title_function,
        .left_parenthesis,
        .string_literal,
        .comma,
        .string_literal,
        .right_parenthesis,
        .eof,
    }, &.{
        .{ .start = 0, .end = 4 },
        .{ .start = 5, .end = 5 },
        .{ .start = 6, .end = 6 },
        .{ .start = 7, .end = 7 },
        .{ .start = 8, .end = 19 },
        .{ .start = 20, .end = 20 },
    });
}

test "Tokenizer: title with number" {
    try testTokenize("title(1, Introduction 1)", &.{
        .title_function,
        .left_parenthesis,
        .string_literal,
        .comma,
        .space,
        .string_literal,
        .space,
        .string_literal,
        .right_parenthesis,
        .eof,
    }, &.{
        .{ .start = 0, .end = 4 },
        .{ .start = 5, .end = 5 },
        .{ .start = 6, .end = 6 },
        .{ .start = 7, .end = 7 },
        .{ .start = 8, .end = 8 },
        .{ .start = 9, .end = 20 },
        .{ .start = 21, .end = 21 },
    });

    try testTokenize("title(1, 1. Introduction)", &.{
        .title_function,
        .left_parenthesis,
        .string_literal,
        .comma,
        .space,
        .string_literal,
        .space,
        .string_literal,
        .right_parenthesis,
        .eof,
    }, &.{
        .{ .start = 0, .end = 4 },
        .{ .start = 5, .end = 5 },
        .{ .start = 6, .end = 6 },
        .{ .start = 7, .end = 7 },
        .{ .start = 8, .end = 8 },
        .{ .start = 9, .end = 10 },
        .{ .start = 11, .end = 11 },
        .{ .start = 12, .end = 23 },
        .{ .start = 24, .end = 24 },
    });
}

test "Tokenizer: bold" {
    try testTokenize("bold(Introduction)", &.{
        .bold_function,
        .left_parenthesis,
        .string_literal,
        .right_parenthesis,
        .eof,
    }, &.{
        .{ .start = 0, .end = 3 },
        .{ .start = 4, .end = 4 },
        .{ .start = 5, .end = 16 },
        .{ .start = 17, .end = 17 },
    });
}

test "Tokenizer: bold recursive" {
    try testTokenize("bold(bold(Introduction))", &.{
        .bold_function,
        .left_parenthesis,
        .bold_function,
        .left_parenthesis,
        .string_literal,
        .right_parenthesis,
        .right_parenthesis,
        .eof,
    }, &.{
        .{ .start = 0, .end = 3 },
        .{ .start = 4, .end = 4 },
        .{ .start = 5, .end = 8 },
        .{ .start = 9, .end = 9 },
        .{ .start = 10, .end = 21 },
        .{ .start = 22, .end = 22 },
    });
}

test "Tokenizer: bold missing left parenthesis" {
    try testTokenize("bold Introduction)", &.{
        .bold_function,
        .space,
        .string_literal,
        .right_parenthesis,
        .eof,
    }, &.{
        .{ .start = 0, .end = 3 },
        .{ .start = 4, .end = 4 },
        .{ .start = 5, .end = 16 },
        .{ .start = 17, .end = 17 },
    });
}

test "Tokenizer: list simple" {
    try testTokenize("list(elem1, elem2)", &.{
        .list_function,
        .left_parenthesis,
        .string_literal,
        .comma,
        .space,
        .string_literal,
        .right_parenthesis,
        .eof,
    }, &.{
        .{ .start = 0, .end = 3 },
        .{ .start = 4, .end = 4 },
        .{ .start = 5, .end = 9 },
        .{ .start = 10, .end = 10 },
        .{ .start = 11, .end = 11 },
        .{ .start = 12, .end = 16 },
        .{ .start = 17, .end = 17 },
    });
}

test "Tokenizer: list complex" {
    try testTokenize("list(Element bold(a), Element b)", &.{
        .list_function,
        .left_parenthesis,
        .string_literal,
        .space,
        .bold_function,
        .left_parenthesis,
        .string_literal,
        .right_parenthesis,
        .comma,
        .space,
        .string_literal,
        .space,
        .string_literal,
        .right_parenthesis,
        .eof,
    }, &.{
        .{ .start = 0, .end = 3 },
        .{ .start = 4, .end = 4 },
        .{ .start = 5, .end = 11 },
        .{ .start = 12, .end = 12 },
        .{ .start = 13, .end = 16 },
        .{ .start = 17, .end = 17 },
        .{ .start = 18, .end = 18 },
        .{ .start = 19, .end = 19 },
        .{ .start = 20, .end = 20 },
        .{ .start = 21, .end = 21 },
        .{ .start = 22, .end = 28 },
        .{ .start = 29, .end = 29 },
        .{ .start = 30, .end = 30 },
        .{ .start = 31, .end = 31 },
    });
}

test "Tokenizer: caption" {
    try testTokenize("caption(\\caption text)", &.{
        .caption_function,
        .left_parenthesis,
        .string_literal,
        .space,
        .string_literal,
        .right_parenthesis,
        .eof,
    }, &.{
        .{ .start = 0, .end = 6 },
        .{ .start = 7, .end = 7 },
        .{ .start = 9, .end = 15 },
        .{ .start = 16, .end = 16 },
        .{ .start = 17, .end = 20 },
    });
}

test "Tokenizer: image" {
    try testTokenize("image(test.png, 100)", &.{
        .image_function,
        .left_parenthesis,
        .string_literal,
        .comma,
        .space,
        .string_literal,
        .right_parenthesis,
        .eof,
    }, &.{
        .{ .start = 0, .end = 4 },
        .{ .start = 5, .end = 5 },
        .{ .start = 6, .end = 13 },
        .{ .start = 14, .end = 14 },
        .{ .start = 15, .end = 15 },
        .{ .start = 16, .end = 18 },
        .{ .start = 19, .end = 19 },
    });
}

test "Tokenizer: figure" {
    try testTokenize("figure(image(image.png, 80), caption(This is a \\caption))", &.{
        .figure_function,
        .left_parenthesis,
        .image_function,
        .left_parenthesis,
        .string_literal,
        .comma,
        .space,
        .string_literal,
        .right_parenthesis,
        .comma,
        .space,
        .caption_function,
        .left_parenthesis,
        .string_literal,
        .space,
        .string_literal,
        .space,
        .string_literal,
        .space,
        .string_literal,
        .right_parenthesis,
        .right_parenthesis,
        .eof,
    }, &.{
        .{ .start = 0, .end = 5 },
        .{ .start = 6, .end = 6 },
        .{ .start = 7, .end = 11 },
        .{ .start = 12, .end = 12 },
        .{ .start = 13, .end = 21 },
        .{ .start = 22, .end = 22 },
        .{ .start = 23, .end = 23 },
        .{ .start = 24, .end = 25 },
        .{ .start = 26, .end = 26 },
        .{ .start = 27, .end = 27 },
        .{ .start = 28, .end = 28 },
        .{ .start = 29, .end = 35 },
        .{ .start = 36, .end = 36 },
        .{ .start = 37, .end = 40 },
        .{ .start = 41, .end = 41 },
        .{ .start = 42, .end = 43 },
        .{ .start = 44, .end = 44 },
        .{ .start = 45, .end = 45 },
        .{ .start = 46, .end = 46 },
        .{ .start = 48, .end = 54 },
        .{ .start = 55, .end = 55 },
        .{ .start = 56, .end = 56 },
    });
}

fn testTokenize(source: [:0]const u8, expected_token_tags: []const Token.Tag, expected_location: []const Token.Location) !void {
    var tokenizer = Tokenizer.init(source, std.testing.allocator);
    var tokens = try tokenizer.tokenize();
    defer tokens.deinit(std.testing.allocator);

    var i: usize = 0;
    for (expected_token_tags) |expected_token_tag| {
        try std.testing.expectEqual(expected_token_tag, tokens.get(i).tag);

        i += 1;
    }

    i = 0;
    for (expected_location) |location| {
        try std.testing.expectEqual(location.start, tokens.get(i).loc.start);
        try std.testing.expectEqual(location.end, tokens.get(i).loc.end);

        i += 1;
    }
}
