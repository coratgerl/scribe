const std = @import("std");

const Ast = @import("./ast.zig").Ast;
const NodeList = Ast.NodeList;
const TokenList = Ast.TokenList;

const token_file = @import("./tokenizer.zig");
const Token = token_file.Token;
const Tokenizer = token_file.Tokenizer;

pub const Parser = struct {
    tokens: []Token.Tag,
    source: []const u8,
    index: usize,
    allocator: std.mem.Allocator,
    nodes: NodeList,
    errors: std.ArrayListUnmanaged(Ast.Error),

    pub const ParserError = error{
        MissingBackslashBeforeCommand,
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

    pub fn parseRoot(self: *Parser) ParserError!void {
        // TODO : Append root
        try self.parseBlock();
    }

    // A block is the content of { }
    // For example in \textbf{Hello}, the content block is Hello
    pub fn parseBlock(self: *Parser) ParserError!void {
        var block_state: Token.TokenKind = .invalid;

        while (self.index < self.tokens.len) : (self.index += 1) {
            const token: Token.Tag = self.tokens[self.index];

            switch (token) {
                .backslash => {
                    block_state = .command;
                },
                .command_textbf => switch (block_state) {
                    .command => {
                        try self.nodes.append(self.allocator, .{
                            .parent_index = 0,
                            .kind = .command,
                            .start = self.index,
                            .end = self.index,
                        });

                        std.debug.print("On est dans le textbf\n", .{});
                    },
                    else => {
                        try self.errors.append(self.allocator, .{
                            .tag = .missing_backslash_before_command,
                            .token_index = self.index,
                        });

                        return ParserError.MissingBackslashBeforeCommand;
                    },
                },
                .string_literal => switch (block_state) {
                    .command => {
                        std.debug.print("On est dans le Hello\n", .{});
                    },
                    else => {},
                },
                else => {},
            }
        }
    }
};

test "Parser: textbf" {
    // \textbf{Hello}
    // Result : [
    //    Node: {
    //        parent_index : -1,
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

    const source = "\\textbf{Hello}";
    const tata = try testParser(source);
    _ = tata;
}

fn testParser(source: []const u8) !void {
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
}
