const std = @import("std");

pub const Token = struct {
    tag: Tag,
    loc: Location,

    pub const Location = struct {
        start: usize,
        end: usize,
    };

    pub const keywords = std.ComptimeStringMap(Tag, .{
        .{ "title", .title_command },
        .{ "bold", .bold_command },
        .{ "figure", .figure_command },
        .{ "image", .image_command },
        .{ "caption", .caption_command },
        .{ "equation", .equation_command },
        .{ "list", .list_command },
    });

    pub const Tag = enum {
        root,
        title_command,
        bold_command,
        figure_command,
        image_command,
        caption_command,
        equation_command,
        list_command,
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
                        std.debug.print("string_literal: {s}\n", .{self.source[result.loc.start..self.index]});
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
    try testTokenize("title(Introduction)", &.{
        .title_command,
        .left_parenthesis,
        .string_literal,
        .right_parenthesis,
        .eof,
    });
}

test "Tokenizer: title with number" {
    try testTokenize("title(Introduction 1)", &.{
        .title_command,
        .left_parenthesis,
        .string_literal,
        .right_parenthesis,
        .eof,
    });

    try testTokenize("title(1. Introduction)", &.{
        .title_command,
        .left_parenthesis,
        .string_literal,
        .right_parenthesis,
        .eof,
    });
}

test "Tokenizer: bold" {
    try testTokenize("bold(Introduction)", &.{
        .bold_command,
        .left_parenthesis,
        .string_literal,
        .right_parenthesis,
        .eof,
    });
}

test "Tokenizer: list" {
    try testTokenize("list(elem1, elem2)", &.{
        .list_command,
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
        .caption_command,
        .left_parenthesis,
        .string_literal,
        .right_parenthesis,
        .eof,
    });
}

test "Tokenizer: image" {
    try testTokenize("image(test.png,100)", &.{
        .image_command,
        .left_parenthesis,
        .string_literal,
        .comma,
        .string_literal,
        .right_parenthesis,
        .eof,
    });
}

// TODO: fix space before caption
test "Tokenizer: figure" {
    try testTokenize("figure(image(image.png, 80),caption(This is a caption))", &.{
        .figure_command,
        .left_parenthesis,
        .image_command,
        .left_parenthesis,
        .string_literal,
        .comma,
        .string_literal,
        .right_parenthesis,
        .comma,
        .caption_command,
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
        std.debug.print("tag: {any}\n", .{tokens.get(i).tag});
        try std.testing.expectEqual(expected_token_tag, tokens.get(i).tag);

        i += 1;
    }
}
