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

pub const nameContinueChars: []const u8 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_";

// pub fn isKeywordWithoutFirstChar(LexerImpl: *const LexerImpl, comptime kws: []const struct{ []const u8, Token.Kind }) ?Token.Kind {
pub fn isKeywordWithoutFirstChar(lexer: *LexerImpl, comptime kws: anytype) ?Token.Kind {
    inline for (kws) |kw| {
        const suffix, const kind = kw;
        const rest = lexer.remaining();
        // a keyword only ends where a name would; `types` is a name, not `type`
        // followed by `s`
        if (mem.startsWith(u8, rest, suffix) and
            (rest.len == suffix.len or !isNameContinue(rest[suffix.len])))
        {
            lexer.advanceBy(@intCast(suffix.len));
            return kind;
        }
    }
    return null;
}

test isKeywordWithoutFirstChar {
    // the `t` handler's keywords, minus the `t` its caller has consumed
    const kws = [_]struct { []const u8, Token.Kind }{
        .{ "ype", .kw_type },
        .{ "rue", .kw_true },
    };

    const Case = struct { src: []const u8, expected: ?Token.Kind = null };
    for ([_]Case{
        .{ .src = "type", .expected = .kw_type },
        .{ .src = "true", .expected = .kw_true },
        .{ .src = "type!", .expected = .kw_type },
        .{ .src = "type ", .expected = .kw_type },
        // a keyword ends where a name would, so these are all names
        .{ .src = "types" },
        .{ .src = "type_" },
        .{ .src = "type1" },
        .{ .src = "truely" },
        // no keyword to match in the first place
        .{ .src = "t" },
        .{ .src = "typ" },
        .{ .src = "tea" },
    }) |case| {
        var lexer = LexerImpl.init(std.testing.allocator, case.src);
        defer lexer.deinit();
        lexer.bump(); // callers have already consumed the first character

        errdefer std.debug.print("Test failed for case: '{s}'\n", .{case.src});
        try std.testing.expectEqual(case.expected, isKeywordWithoutFirstChar(&lexer, &kws));

        if (case.expected) |kind| {
            // the whole keyword got consumed
            const suffix = for (kws) |kw| {
                if (kw[1] == kind) break kw[0];
            } else return error.KindNotInKeywordTable;
            try std.testing.expectEqualStrings(suffix, case.src[1..lexer._cur]);
        } else {
            // nothing past the first character, leaving it to the name lexer
            try std.testing.expectEqual(1, lexer._cur);
        }
    }
}

test nameContinueChars {
    for (nameContinueChars) |c| {
        try std.testing.expect(isNameContinue(c));
    }
}
