const std = @import("std");

const Parser = @import("./parser.zig").Parser;

const token_file = @import("./tokenizer.zig");
const Token = token_file.Token;
const Tokenizer = token_file.Tokenizer;

pub const Node = struct {
    parent_index: usize,
    kind: NodeKind,
    start: usize,
    end: usize,
    // TODO : For search optimization we will need to get the an array of children index

    pub const NodeKind = Token.Tag;
};

pub const Ast = struct {
    source: []const u8,
    tokens: TokenList.Slice,
    nodes: NodeList.Slice,
    allocator: std.mem.Allocator,

    pub const TokenList = std.MultiArrayList(struct {
        tag: Token.Tag,
        start: usize,
    });

    pub const NodeList = std.MultiArrayList(Node);

    pub const Error = struct {
        tag: Tag,
        token_index: usize,

        pub const Tag = enum {
            missing_left_parenthesis,
            missing_right_parenthesis,
        };
    };

    pub fn init(allocator: std.mem.Allocator, source: []const u8) !Ast {
        var tokenizer = Tokenizer.init(source, std.testing.allocator);
        var tokens = try tokenizer.tokenize();
        defer tokens.deinit(std.testing.allocator);

        const parser = Parser.init(allocator, tokens.items(.tag), tokens.items(.loc), source, .{});
        _ = parser;

        return .{
            .source = source,
            .tokens = tokens.toOwnedSlice(),
            .allocator = allocator,
        };
    }
};
