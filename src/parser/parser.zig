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

    pub fn init(allocator: std.mem.Allocator, tokens: []Token.Tag, source: []const u8, nodes: NodeList) Parser {
        return Parser{
            .tokens = tokens,
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
    pub fn expectNextToken(self: *Parser, tag: Token.Tag) bool {
        if (self.index + 1 >= self.tokens.len) return false;

        return self.tokens[self.index + 1] == tag;
    }

    pub fn expectPreviousToken(self: *Parser, tag: Token.Tag) bool {
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

        try self.parseBlock();
    }

    fn switchToken(self: *Parser, token: Token.Tag) ParserError!void {
        return switch (token) {
            .bold_function => {
                try self.parseFunction(0);
            },
            else => {},
        };
    }

    pub fn parseBlock(self: *Parser) ParserError!void {
        while (self.index < self.tokens.len) : (self.index += 1) {
            const token: Token.Tag = self.tokens[self.index];

            try self.switchToken(token);
        }
    }

    fn parseFunctionArgument(self: *Parser, function_index: usize) ParserError!void {
        if (!self.expectNextToken(Token.Tag.left_parenthesis)) {
            try self.errors.append(self.allocator, .{
                .tag = AstError.Tag.missing_left_parenthesis,
                .token_index = self.index,
            });
            return;
        }

        // We skip the parenthesis
        self.index += 2;

        // For the recursive case : bold(bold(Hello))
        if (self.tokens[self.index] != Token.Tag.string_literal) {
            try self.switchToken(self.tokens[self.index]);
        }

        while (self.index < self.tokens.len) : (self.index += 1) {
            const token = self.tokens[self.index];

            switch (token) {
                .string_literal => {
                    try self.nodes.append(self.allocator, .{
                        .parent_index = function_index,
                        .kind = .string_literal,
                        .start = self.index,
                        .end = self.index,
                    });
                },
                .right_parenthesis => {
                    self.index += 1;
                    break;
                },
                .comma => {
                    // Nothing to do but it's explicit
                },
                else => {},
            }
        }

        if (!self.expectPreviousToken(Token.Tag.right_parenthesis)) {
            try self.errors.append(self.allocator, .{
                .tag = AstError.Tag.missing_right_parenthesis,
                .token_index = self.index,
            });
        }
    }

    pub fn parseFunction(self: *Parser, parent_index: usize) ParserError!void {
        _ = parent_index;

        // TODO : Add test to check the start and end index
        try self.nodes.append(self.allocator, .{
            .parent_index = self.nodes.len - 1,
            .kind = .bold_function,
            .start = self.index,
            .end = self.index,
        });

        try self.parseFunctionArgument(self.nodes.len - 1);
    }
};

test "Parser: bold" {
    const source = "bold(Hello)";
    try testParser(source, &.{
        .root,
        .bold_function,
        .string_literal,
    }, &.{
        0,
        0,
        1,
    }, &.{});
}

test "Parser: missing right parenthesis" {
    const source = "bold(Hello";
    try testParser(source, &.{ .root, .bold_function, .string_literal }, &.{
        0,
        0,
        1,
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
        0,
        0,
        1,
        2,
    }, &.{});
}

fn testParser(source: []const u8, expected_tokens_kinds: []const Node.NodeKind, parent_index: []const usize, errors: []const AstError.Tag) !void {
    var tokenizer = Tokenizer.init(source, std.testing.allocator);
    var tokens = try tokenizer.tokenize();
    defer tokens.deinit(std.testing.allocator);

    var parser = Parser.init(std.testing.allocator, tokens.items(.tag), source, .{});
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
