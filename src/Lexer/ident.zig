const std = @import("std");
const ascii = std.ascii;
const mem = std.mem;
const LexerImpl = @import("LexerImpl.zig");
const Token = @import("Token.zig");

// Name ::
// 
// - NameStart NameContinue\* [lookahead != NameContinue]
// 
// NameStart ::
// 
// - Letter
// - `_`
// 
// NameContinue ::
// 
// - Letter
// - Digit
// - `_`
pub fn isNameStart(c: u8) bool {
    return ascii.isAlphabetic(c) or c == '_';
}

pub fn isNameContinue(c: u8) bool {
    return ascii.isAlphanumeric(c) or c == '_';
}

// pub fn isKeywordWithoutFirstChar(LexerImpl: *const LexerImpl, comptime kws: []const struct{ []const u8, Token.Kind }) ?Token.Kind {
pub fn isKeywordWithoutFirstChar(lexer: *LexerImpl, comptime kws: anytype) ?Token.Kind {
    inline for (kws) |kw| {
        const suffix, const kind = kw;
        if (mem.startsWith(u8, lexer.remaining(), suffix)) {
            lexer.advanceBy(@intCast(suffix.len));
            return kind;
        }
    }
    return null;
}
