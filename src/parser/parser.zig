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

    pub fn parseRoot(self: *Parser) !void {
        try self.nodes.append(self.allocator, .{
            .parent_index = 0,
            .kind = .root,
            .start = 0,
            .end = 0,
        });

        try self.parseBlock();
    }

    // A block is the content of { }
    // For example in \textbf{Hello}, the content block is Hello
    pub fn parseBlock(self: *Parser) !void {
        var block_state: Token.TokenKind = .invalid;

        var left_brace_count: usize = 0;
        var right_brace_count: usize = 0;
        var parent_index: usize = 0;

        while (self.index < self.tokens.len) : (self.index += 1) {
            const token: Token.Tag = self.tokens[self.index];

            switch (token) {
                .backslash => {
                    block_state = .command;
                },
                .left_brace => {
                    left_brace_count += 1;
                },
                .right_brace => {
                    // A block is finished when the number of left brace is equal to the number of right brace
                    // For example \textbf{\textbf{\textbf{Hello}}}
                    if (left_brace_count == right_brace_count) {
                        break;
                    }
                    right_brace_count += 1;
                },
                .command_textbf => switch (block_state) {
                    .command => {
                        try self.nodes.append(self.allocator, .{
                            .parent_index = parent_index,
                            .kind = .command,
                            .start = self.index,
                            .end = self.index,
                        });

                        parent_index = self.nodes.len - 1;
                    },
                    else => {
                        try self.errors.append(self.allocator, .{
                            .tag = .missing_backslash_before_command,
                            .token_index = self.index,
                        });

                        // TODO : Handle error ?
                    },
                },
                .string_literal => switch (block_state) {
                    .command => {
                        try self.nodes.append(self.allocator, .{
                            .parent_index = parent_index,
                            .kind = .string_literal,
                            .start = self.index,
                            .end = self.index,
                        });
                    },
                    else => {},
                },
                else => {},
            }
        }

        if (left_brace_count != right_brace_count) {
            if (left_brace_count > right_brace_count) {
                try self.errors.append(self.allocator, .{
                    .tag = .missing_right_brace,
                    .token_index = self.index,
                });
            } else {
                try self.errors.append(self.allocator, .{
                    .tag = .missing_left_brace,
                    .token_index = self.index,
                });
            }
        }
    }
};

// Example of valid structure:
// \textbf{Hello}
// Result : [
//    Node: {
//        parent_index : 0,
//        type: .root,
//        start: 0,
//        end: 0,
//    },
//    Node: {
//        parent_index : 0,
//        type: .command,
//        start: 0,
//        end: 13,
//    },
//    Node: {
//        parent_index : 1,
//        type: .string_litteral,
//        start: 9,
//        end: 13,
//    },
// ]

test "Parser: textbf" {
    const source = "\\textbf{Hello}";
    try testParser(source, &.{
        .root,
        .command,
        .string_literal,
    }, &.{
        0,
        0,
        1,
    }, &.{});
}

test "Parser: recursive textbf" {
    const source = "\\textbf{\\textbf{Hello}}";
    try testParser(source, &.{
        .root,
        .command,
        .command,
        .string_literal,
    }, &.{
        0,
        0,
        1,
        2,
    }, &.{});
}

test "Parser: double recursive textbf" {
    const source = "\\textbf{\\textbf{\\textbf{Hello}}}";
    try testParser(source, &.{
        .root,
        .command,
        .command,
        .command,
        .string_literal,
    }, &.{
        0,
        0,
        1,
        2,
        3,
    }, &.{});
}

test "Parser: missing one right brace" {
    const source = "\\textbf{\\textbf{\\textbf{Hello}}";

    try testParser(source, &.{
        .root,
        .command,
        .command,
        .command,
        .string_literal,
    }, &.{
        0,
        0,
        1,
        2,
        3,
    }, &.{
        .missing_right_brace,
    });
}

fn testParser(source: []const u8, expected_tokens_kinds: []const Token.TokenKind, parent_index: []const usize, errors: []const AstError.Tag) !void {
    var tokens = TokenList{};
    defer tokens.deinit(std.testing.allocator);

    try tokens.ensureTotalCapacity(std.testing.allocator, source.len);

    var tokenizer = Tokenizer.init(source);

    while (true) {
        const token = tokenizer.next();
        try tokens.append(std.testing.allocator, .{
            .tag = token.tag,
            .start = token.loc.start,
        });

        if (token.tag == .eof)
            break;
    }

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
