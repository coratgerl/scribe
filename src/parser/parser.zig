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

    pub fn parseBlock(self: *Parser) ParserError!void {
        while (self.index < self.tokens.len) : (self.index += 1) {
            const token: Token.Tag = self.tokens[self.index];

            switch (token) {
                .usepackage_command, .textbf_command => {
                    try self.parseCommand();
                },
                else => {},
            }
        }
    }

    // This function can only be call by parseCommand (the checks of brace and brackets are already done)
    // Example of valid command : \textbf{Hello} or \usepackage[utf8]{test}
    fn parseCommandArgument(self: *Parser, parent_index: usize) ParserError!void {
        self.index += 2;

        // Recursive case
        if (self.tokens[self.index] == Token.Tag.backslash and self.tokens.len > self.index + 1) {
            self.index += 1;
            try self.parseCommand();
        }

        var right_brace_encountered = false;

        while (self.index < self.tokens.len) : (self.index += 1) {
            const token: Token.Tag = self.tokens[self.index];

            switch (token) {
                .comma => {},
                .string_literal => {
                    std.debug.print("Add node: argument and {}\n", .{parent_index});
                    try self.nodes.append(self.allocator, .{
                        .parent_index = parent_index,
                        .kind = .argument,
                        .start = self.index,
                        .end = self.index,
                    });
                },
                .right_brace => {
                    self.index += 1;

                    right_brace_encountered = true;
                    break;
                },
                else => {},
            }
        }

        if (!right_brace_encountered) {
            try self.errors.append(self.allocator, .{
                .tag = .missing_right_brace,
                .token_index = self.index,
            });

            return;
        }
    }

    fn parseCommandOption(self: *Parser, parent_index: usize) ParserError!void {
        self.index += 2;

        std.debug.print("Add node: option and {}\n", .{parent_index});

        try self.nodes.append(self.allocator, .{
            .parent_index = parent_index,
            .kind = .option,
            .start = self.index,
            .end = self.index,
        });

        if (!self.expectNextToken(Token.Tag.right_bracket)) {
            try self.errors.append(self.allocator, .{
                .tag = .missing_right_bracket,
                .token_index = self.index,
            });
        }

        self.index += 1;
    }

    pub fn parseCommand(self: *Parser) ParserError!void {
        if (!self.expectPreviousToken(Token.Tag.backslash)) {
            try self.errors.append(self.allocator, .{
                .tag = .missing_backslash_before_command,
                .token_index = self.index,
            });

            return;
        }

        const parent_index = self.nodes.len;
        const is_next_token_bracket = self.expectNextToken(Token.Tag.left_bracket);
        const is_next_token_brace = self.expectNextToken(Token.Tag.left_brace);

        // Bracket is optional because it's use for command's options
        if (!is_next_token_bracket or !is_next_token_brace) {
            try self.errors.append(self.allocator, .{
                .tag = .missing_left_brace,
                .token_index = self.index,
            });
        }

        std.debug.print("Add command : {} and {}\n", .{ self.tokens[self.index], parent_index });

        try self.nodes.append(self.allocator, .{
            .parent_index = self.nodes.len - 1,
            .kind = self.tokens[self.index],
            .start = self.index,
            .end = self.index,
        });

        // We check if there is option if it is the case we add and increment to go to the brace
        if (is_next_token_bracket) {
            try self.parseCommandOption(parent_index);
        }

        try self.parseCommandArgument(parent_index);
    }
};

// Example of valid structure:
// \begin{document}
// \textbf{Hello}
// \end{document}
// Result : [
//    Node: {
//        parent_index : 0,
//        type: .root,
//        start: 0,
//        end: 0,
//    },
//    Node: {
//        parent_index : 0,
//        type: .begin_command,
//        start: 0,
//        end: 44,
//    },
//    Node: {
//        parent_index : 1,
//        type: .string_litteral,
//        start: 7,
//        end: 15,
//    },
//    Node: {
//        parent_index : 1,
//        type: .textbf_command,
//        start: 16,
//        end: 22,
//    },
//    Node: {
//        parent_index : 3,
//        type: .string_litteral,
//        start: 23,
//        end: 28,
//    },
//    Node: {
//        parent_index : 0,
//        type: .command,
//        start: 29,
//        end: 32,
//    },
//    Node: {
//        parent_index : 0,
//        type: .string_literal,
//        start: 29,
//        end: 40,
//    },
// ]

// test "Parser: textbf" {
//     const source = "\\textbf{Hello}";
//     try testParser(source, &.{
//         .root,
//         .textbf_command,
//         .argument,
//     }, &.{
//         0,
//         0,
//         1,
//     }, &.{});
// }

// test "Parser: recursive textbf" {
//     const source = "\\textbf{\\textbf{Hello}}";
//     try testParser(source, &.{
//         .root,
//         .textbf_command,
//         .textbf_command,
//         .argument,
//     }, &.{
//         0,
//         0,
//         1,
//         2,
//     }, &.{});
// }

// test "Parser: double recursive textbf" {
//     const source = "\\textbf{\\textbf{\\textbf{Hello}}}";
//     try testParser(source, &.{
//         .root,
//         .textbf_command,
//         .textbf_command,
//         .textbf_command,
//         .argument,
//     }, &.{
//         0,
//         0,
//         1,
//         2,
//         3,
//     }, &.{});
// }

// test "Parser: missing one right brace" {
//     const source = "\\textbf{\\textbf{\\textbf{Hello}}";

//     try testParser(source, &.{
//         .root,
//         .textbf_command,
//         .textbf_command,
//         .textbf_command,
//         .argument,
//     }, &.{
//         0,
//         0,
//         1,
//         2,
//         3,
//     }, &.{
//         .missing_right_brace,
//     });
// }

// test "Parser: missing one left brace" {
// const source = "\\textbf{\\textbf{\\textbfHello}}}";

// try testParser(source, &.{
//     .root,
//     .textbf_command,
//     .textbf_command,
// }, &.{
//     0,
//     0,
//     1,
// }, &.{
//     .missing_left_brace,
// });

// const source2 = "\\textbf\\textbf{\\textbf{Hello}}}";

// try testParser(source2, &.{
//     .root,
//     .textbf_command,
//     .textbf_command,
//     .argument,
// }, &.{
//     0,
//     0,
//     1,
//     2,
// }, &.{
//     .missing_left_brace,
// });

// const source3 = "\\textbf{\\textbf\\textbf{Hello}}}";

// try testParser(source3, &.{
//     .root,
//     .textbf_command,
//     .argument,
// }, &.{
//     0,
//     0,
//     1,
// }, &.{
//     .missing_left_brace,
// });
// }

// test "Parser: get command options" {
//     const source = "\\usepackage[utf8]{test}";

//     try testParser(source, &.{
//         .root,
//         .usepackage_command,
//         .option,
//         .argument,
//     }, &.{
//         0,
//         0,
//         1,
//         1,
//     }, &.{});
// }

fn testParser(source: []const u8, expected_tokens_kinds: []const Node.NodeKind, parent_index: []const usize, errors: []const AstError.Tag) !void {
    _ = expected_tokens_kinds;
    _ = parent_index;
    _ = errors;

    var tokenizer = Tokenizer.init(source, std.testing.allocator);
    var tokens = try tokenizer.tokenize();
    defer tokens.deinit(std.testing.allocator);

    var parser = Parser.init(std.testing.allocator, tokens.items(.tag), source, .{});
    defer parser.deinit();

    try parser.parseRoot();

    const slice = parser.nodes.slice();
    _ = slice;

    const errors_slice = parser.errors.slice();
    _ = errors_slice;

    // var i: usize = 0;
    // for (expected_tokens_kinds) |expected_token_kind| {
    //     try std.testing.expectEqual(expected_token_kind, slice.get(i).kind);

    //     i += 1;
    // }

    // i = 0;
    // for (parent_index) |index| {
    //     try std.testing.expectEqual(index, slice.get(i).parent_index);

    //     i += 1;
    // }

    // i = 0;
    // for (errors) |error_tag| {
    //     try std.testing.expectEqual(error_tag, errors_slice.get(i).tag);

    //     i += 1;
    // }
}
