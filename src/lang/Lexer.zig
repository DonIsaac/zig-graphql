const Lexer = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const LexerImpl = @import("Lexer/LexerImpl.zig");

pub const Token = @import("Lexer/Token.zig");

_impl: LexerImpl,

pub const Error = LexerImpl.Error;

pub fn init(allocator: Allocator, source_text: []const u8) Lexer {
    return .{ ._impl = LexerImpl.init(allocator, source_text) };
}

pub fn deinit(self: *Lexer) void {
    self._impl.deinit();
    self.* = undefined;
}

pub fn next(self: *Lexer) !?Token {
    return self._impl.next(.Whitespace);
}

pub inline fn source(self: *const Lexer) []const u8 {
    return self._impl.source;
}

test {
    _ = @import("Lexer/test/Lexer.test.zig");
}
