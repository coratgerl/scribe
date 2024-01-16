const std = @import("std");

const ast_file = @import("./ast.zig");
const Node = ast_file.Node;
const AstError = ast_file.Ast.Error;
const NodeList = ast_file.Ast.NodeList;
const TokenList = ast_file.Ast.TokenList;

const token_file = @import("./tokenizer.zig");
const Token = token_file.Token;
const Tokenizer = token_file.Tokenizer;

pub const Parser = struct {
    tokens: []Token.Tag,
    loc: []Token.Location,
    source: []const u8,
    index: usize,
    allocator: std.mem.Allocator,
    nodes: NodeList,
    errors: std.MultiArrayList(AstError),

    pub const ParserError = error{
        MissingLeftBrace,
        MissingRightBrace,
        MissingBackslashBeforeCommand,
        MissingArgument,
        OutOfMemory,
    };

    const State = enum {
        start,
        string_literal,
    };

    pub fn init(allocator: std.mem.Allocator, tokens: []Token.Tag, loc: []Token.Location, source: []const u8, nodes: NodeList) Parser {
        return Parser{
            .tokens = tokens,
            .loc = loc,
            .source = source,
            .index = 0,
            .allocator = allocator,
            .nodes = nodes,
            .errors = .{},
        };
    }

    pub fn deinit(self: *Parser) void {
        self.nodes.deinit(self.allocator);
        self.errors.deinit(self.allocator);
    }

    fn expectNextToken(self: *Parser, tag: Token.Tag) bool {
        if (self.index + 1 >= self.tokens.len) return false;

        return self.tokens[self.index + 1] == tag;
    }

    fn expectPreviousToken(self: *Parser, tag: Token.Tag) bool {
        if (self.index == 0) return false;

        return self.tokens[self.index - 1] == tag;
    }

    pub fn parseRoot(self: *Parser) ParserError!void {
        try self.nodes.append(self.allocator, .{
            .parent_index = 0,
            .kind = .root,
            .start = 0,
            .end = 0,
        });

        try self.parseBlock(0);
    }

    fn switchToken(self: *Parser, token: Token.Tag, parent_index: usize) ParserError!void {
        return switch (token) {
            .list_function,
            .equation_function,
            .caption_function,
            .title_function,
            .bold_function,
            => {
                try self.parseFunction(parent_index);
            },
            else => {},
        };
    }

    pub fn parseBlock(self: *Parser, parent_index: usize) ParserError!void {
        while (self.index < self.tokens.len) : (self.index += 1) {
            const token = self.tokens[self.index];

            try self.switchToken(token, parent_index);
        }
    }

    fn parseFunctionArguments(self: *Parser, function_index: usize) ParserError!void {
        // Were are on the left parenthesis and we go to the first argument
        self.index += 1;

        var state: State = .start;

        var start_index = self.loc[self.index].start;

        while (self.index < self.tokens.len) : (self.index += 1) {
            const token = self.tokens[self.index];

            // std.debug.print("Token : {any}\n", .{token});

            switch (state) {
                .start => {
                    switch (token) {
                        .space => {
                            start_index += 1;
                        },
                        .string_literal => {
                            state = .string_literal;
                        },
                        else => {
                            // For the recursive case : Example bold(bold(Hello))
                            try self.switchToken(self.tokens[self.index], function_index);
                        },
                    }
                },
                .string_literal => {
                    switch (token) {
                        .string_literal => {},
                        .space => {
                            // Example of the use case : list(Example bold(Hello))
                            if (!self.expectNextToken(Token.Tag.string_literal)) {
                                // std.debug.print("Add : string_literal => start :{d} - end {d} - parent_index : {d}\n", .{ start_index, self.loc[self.index].end, function_index });

                                try self.nodes.append(self.allocator, .{
                                    .parent_index = function_index,
                                    .kind = .string_literal,
                                    .start = start_index,
                                    .end = self.loc[self.index].end,
                                });
                            }
                        },
                        .comma => {
                            if (self.expectPreviousToken(Token.Tag.string_literal)) {
                                // std.debug.print("Add : string_literal => start :{d} - end {d} - parent_index : {d}\n", .{ start_index, self.loc[self.index].end, function_index });

                                try self.nodes.append(self.allocator, .{
                                    .parent_index = function_index,
                                    .kind = .string_literal,
                                    .start = start_index,
                                    .end = self.loc[self.index].end - 1,
                                });
                            }

                            try self.parseFunctionArguments(function_index);

                            return;
                        },
                        .right_parenthesis => {
                            // std.debug.print("Add : string_literal => start :{d} - end {d} - parent_index {d}\n", .{ start_index, self.loc[self.index].end - 1, function_index });

                            try self.nodes.append(self.allocator, .{
                                .parent_index = function_index,
                                .kind = .string_literal,
                                .start = start_index,
                                .end = self.loc[self.index].end - 1,
                            });

                            return;
                        },
                        else => {
                            // For the recursive case : Example bold(bold(Hello))
                            try self.switchToken(self.tokens[self.index], function_index);
                        },
                    }
                },
            }
        }
    }

    fn parseFunction(self: *Parser, parent_index: usize) ParserError!void {
        // std.debug.print("Add function :{any} - start : {d} - end : {d} - parent_index : {d} \n", .{ self.tokens[self.index], self.loc[self.index].start, self.loc[self.index].end, parent_index });
        try self.nodes.append(self.allocator, .{
            .parent_index = parent_index,
            .kind = self.tokens[self.index],
            .start = self.loc[self.index].start,
            .end = self.loc[self.index].end,
        });

        if (!self.expectNextToken(Token.Tag.left_parenthesis)) {
            try self.errors.append(self.allocator, .{
                .tag = AstError.Tag.missing_left_parenthesis,
                .token_index = self.index,
            });
            return;
        }

        // We are the character just before the left parenthesis and we go to the parenthesis
        self.index += 1;

        try self.parseFunctionArguments(self.nodes.len - 1);

        if (!self.expectPreviousToken(Token.Tag.right_parenthesis)) {
            try self.errors.append(self.allocator, .{
                .tag = AstError.Tag.missing_right_parenthesis,
                .token_index = self.index,
            });
        }
    }
};

test "Parser: bold" {
    const source = "bold(Hello world)";

    try testParser(source, &.{
        .root,
        .bold_function,
        .string_literal,
    }, &.{
        .{ .start = 0, .end = 0 },
        .{ .start = 0, .end = 3 },
        .{ .start = 5, .end = 15 },
    }, &.{
        0,
        0,
        1,
    }, &.{});
}

test "Parser: missing right parenthesis" {
    const source = "bold(Hello";

    try testParser(source, &.{
        .root,
        .bold_function,
    }, &.{
        .{ .start = 0, .end = 0 },
        .{ .start = 0, .end = 3 },
    }, &.{
        0,
        0,
    }, &.{
        .missing_right_parenthesis,
    });
}

test "Parser: recursive bold function" {
    const source = "bold(bold(Hello))";
    try testParser(source, &.{
        .root,
        .bold_function,
        .bold_function,
        .string_literal,
    }, &.{
        .{ .start = 0, .end = 0 },
        .{ .start = 0, .end = 3 },
        .{ .start = 5, .end = 8 },
        .{ .start = 10, .end = 14 },
    }, &.{
        0,
        0,
        1,
        2,
    }, &.{});

    const source2 = "bold(bold(Hello) )";
    try testParser(source2, &.{
        .root,
        .bold_function,
        .bold_function,
        .string_literal,
        .string_literal,
    }, &.{
        .{ .start = 0, .end = 0 },
        .{ .start = 0, .end = 3 },
        .{ .start = 5, .end = 8 },
        .{ .start = 10, .end = 14 },
        .{ .start = 16, .end = 16 },
    }, &.{
        0,
        0,
        1,
        2,
        1,
    }, &.{});
}

test "Parser: missing left parenthesis" {
    const source = "bold Hello)";
    try testParser(source, &.{
        .root,
        .bold_function,
    }, &.{
        .{ .start = 0, .end = 0 },
        .{ .start = 0, .end = 3 },
    }, &.{
        0,
        0,
    }, &.{
        .missing_left_parenthesis,
    });
}

test "Parser: title function" {
    const source = "title(1, Hello )";
    try testParser(source, &.{
        .root,
        .title_function,
        .string_literal,
        .string_literal,
    }, &.{
        .{ .start = 0, .end = 0 },
        .{ .start = 0, .end = 4 },
        .{ .start = 6, .end = 6 },
        .{ .start = 9, .end = 14 },
    }, &.{
        0,
        0,
        1,
        1,
    }, &.{});
}

test "Parser: caption function" {
    const source = "caption(Hello)";
    try testParser(source, &.{
        .root,
        .caption_function,
        .string_literal,
    }, &.{
        .{ .start = 0, .end = 0 },
        .{ .start = 0, .end = 6 },
        .{ .start = 8, .end = 12 },
    }, &.{
        0,
        0,
        1,
    }, &.{});
}

test "Parser: equation function" {
    const source = "equation(Hello)";
    try testParser(source, &.{
        .root,
        .equation_function,
        .string_literal,
    }, &.{
        .{ .start = 0, .end = 0 },
        .{ .start = 0, .end = 7 },
        .{ .start = 9, .end = 13 },
    }, &.{
        0,
        0,
        1,
    }, &.{});
}

test "Parser: list function" {
    const source = "list(Hello)";
    try testParser(source, &.{
        .root,
        .list_function,
        .string_literal,
    }, &.{
        .{ .start = 0, .end = 0 },
        .{ .start = 0, .end = 3 },
        .{ .start = 5, .end = 9 },
    }, &.{
        0,
        0,
        1,
    }, &.{});

    const source2 = "list(Hello, World)";

    try testParser(source2, &.{
        .root,
        .list_function,
        .string_literal,
        .string_literal,
    }, &.{
        .{ .start = 0, .end = 0 },
        .{ .start = 0, .end = 3 },
        .{ .start = 5, .end = 9 },
        .{ .start = 12, .end = 16 },
    }, &.{
        0,
        0,
        1,
        1,
    }, &.{});

    const source3 = "list(Hello, World, !)";

    try testParser(source3, &.{
        .root,
        .list_function,
        .string_literal,
        .string_literal,
        .string_literal,
    }, &.{
        .{ .start = 0, .end = 0 },
        .{ .start = 0, .end = 3 },
        .{ .start = 5, .end = 9 },
        .{ .start = 12, .end = 16 },
        .{ .start = 19, .end = 19 },
    }, &.{
        0,
        0,
        1,
        1,
        1,
    }, &.{});

    const source4 = "list(Element bold(a), Element b)";

    try testParser(source4, &.{
        .root,
        .list_function,
        .string_literal,
        .bold_function,
        .string_literal,
        .string_literal,
    }, &.{
        .{ .start = 0, .end = 0 },
        .{ .start = 0, .end = 3 },
        .{ .start = 5, .end = 12 },
        .{ .start = 13, .end = 16 },
        .{ .start = 18, .end = 18 },
        .{ .start = 22, .end = 30 },
    }, &.{
        0,
        0,
        1,
        1,
        3,
        1,
    }, &.{});
}

fn testParser(source: []const u8, expected_tokens_kinds: []const Node.NodeKind, expected_location: []const Token.Location, parent_index: []const usize, errors: []const AstError.Tag) !void {
    var tokenizer = Tokenizer.init(source, std.testing.allocator);
    var tokens = try tokenizer.tokenize();
    defer tokens.deinit(std.testing.allocator);

    var parser = Parser.init(std.testing.allocator, tokens.items(.tag), tokens.items(.loc), source, .{});
    defer parser.deinit();

    try parser.parseRoot();

    const slice = parser.nodes.slice();

    const errors_slice = parser.errors.slice();

    var i: usize = 0;
    for (expected_tokens_kinds) |expected_token_kind| {
        try std.testing.expectEqual(expected_token_kind, slice.get(i).kind);

        i += 1;
    }

    i = 0;
    for (expected_location) |location| {
        try std.testing.expectEqual(location.start, slice.get(i).start);
        try std.testing.expectEqual(location.end, slice.get(i).end);

        i += 1;
    }

    i = 0;
    for (parent_index) |index| {
        try std.testing.expectEqual(index, slice.get(i).parent_index);

        i += 1;
    }

    i = 0;
    for (errors) |error_tag| {
        try std.testing.expectEqual(error_tag, errors_slice.get(i).tag);

        i += 1;
    }
}
