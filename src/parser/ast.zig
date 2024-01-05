const std = @import("std");

const Parser = @import("./parser.zig").Parser;

const token_file = @import("./tokenizer.zig");
const Token = token_file.Token;
const Tokenizer = token_file.Tokenizer;

pub const Node = struct {
    tag: Token.Tag,
    start: usize,
    expr: Expression,

    pub const Expression = struct {
        start: usize,
        end: usize,
    };
};

pub const Ast = struct {
    source: []const u8,
    tokens: TokenList.Slice,
    allocator: std.mem.Allocator,

    pub const TokenList = std.MultiArrayList(struct {
        tag: Token.Tag,
        start: usize,
    });

    pub const NodeList = std.MultiArrayList(Node);

    pub fn init(allocator: std.mem.Allocator, source: []const u8) !Ast {
        var tokens = Ast.TokenList{};
        defer tokens.deinit(allocator);

        // TODO : We will need to estimated the ratio of token in latex
        try tokens.ensureTotalCapacity(allocator, source.len);

        var tokenizer = Tokenizer.init(source);

        while (true) {
            const token = tokenizer.next();
            try tokens.append(allocator, .{
                .tag = token.tag,
                .start = token.loc.start,
            });

            if (token.tag == .eof)
                break;
        }

        const parser = Parser.init(allocator, tokens.items(.tag), source);
        _ = parser;

        return .{
            .source = source,
            .tokens = tokens.toOwnedSlice(),
            .allocator = allocator,
        };
    }
};
