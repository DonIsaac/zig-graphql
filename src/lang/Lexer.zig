const Lexer = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const LexerImpl = @import("Lexer/LexerImpl.zig");

pub const Token = @import("Lexer/Token.zig");

_impl: LexerImpl,

pub const Error = LexerImpl.Error;

pub const Checkpoint = struct {
    errors: u32,
    tok: Token,
    cur: u32,
};

pub fn init(allocator: Allocator, source_text: []const u8) Lexer {
    return .{ ._impl = LexerImpl.init(allocator, source_text) };
}

pub fn deinit(self: *Lexer) void {
    self._impl.deinit();
    self.* = undefined;
}

pub fn next(self: *Lexer) Error!?Token {
    return self._impl.next(.Whitespace);
}

pub inline fn source(self: *const Lexer) []const u8 {
    return self._impl.source;
}

pub fn checkpoint(self: *const Lexer) Checkpoint {
    // We'll add fatal_error to Checkpoint if it's needed.
    std.debug.assert(self._impl.fatal_error == null);
    return .{
        .cur = self._impl._cur,
        .errors = self._impl.errors.items.len,
        .tok = self._impl.tok,
    };
}

pub fn restore(self: *Lexer, ckpt: Checkpoint) void {
    self._impl.errors.shrinkRetainingCapacity(ckpt.errors);
    self._impl._cur = ckpt.cur;
    self._impl.tok = ckpt.tok;
    self._impl.fatal_error = null;
}

test {
    _ = @import("Lexer/test/Lexer.test.zig");
}
