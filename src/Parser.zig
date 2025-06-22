const Parser = @This();

const std = @import("std");
const Lexer = @import("Lexer.zig");
const Ast = @import("Ast.zig");
const Allocator = std.mem.Allocator;

const ParserImpl = @import("Parser/ParserImpl.zig");

// lexer: Lexer,
_impl: ParserImpl,

pub fn init(allocator: Allocator, source: []const u8) Parser {
    return .{ ._impl = ParserImpl.init(allocator, source) };
}

pub fn parse(self: *Parser) !Ast.Document {
    return .{};
}
