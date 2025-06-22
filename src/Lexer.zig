const Lexer = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const LexerImpl = @import("Lexer/LexerImpl.zig");

pub const Token = @import("Lexer/Token.zig");

_impl: LexerImpl,

pub fn init(allocator: Allocator, source: []const u8) Lexer {
    return .{ ._impl = LexerImpl.init(allocator, source) };
}

pub fn next(self: *Lexer) !?Token {
    return self._impl.next(.Whitespace);
}

test {
    _ = @import("Lexer/test/Lexer.test.zig");
}
