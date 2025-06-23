const std = @import("std");
const util = @import("../../util.zig");
const LexerImpl = @import("LexerImpl.zig");
const Span = @import("../../Span.zig");

const Token = @import("Token.zig");
const assert = std.debug.assert;
const mem = std.mem;

const triple_quote =
    \\"""
;

pub fn lexStringValue(l: *LexerImpl) Token.Kind {
    l.expect('"');
    if (l.eat('"')) {
        if (l.eat('"')) {
            // block string
            if (l._cur + 3 >= l.source.len) {
                return unclosedBlockString(l);
            }
            const rest = l.remaining();
            std.debug.assert(rest.len >= 3);
            // if ()
            const end = mem.indexOf(u8, rest, triple_quote) orelse return unclosedBlockString(l);
            l.advanceBy(@intCast(end + triple_quote.len));
            return .block_string_value;
        }

        return .string_value; // empty string
    }

    const src = l.source;
    var cursor: usize = l._cur + 1;

    // find the closing quote. Backtrack from each quote looking for escapes.
    while (cursor < src.len) {
        // note: this is SIMD, so next index + backtrack is faster than char-by-char
        const closingPos = mem.indexOfScalarPos(u8, src, cursor, '"') orelse return unclosedString(l);
        var num_backslashes: usize = 0;
        while (closingPos > 0 and src[closingPos - num_backslashes - 1] == '\\') {
            num_backslashes += 1;
        }
        if (num_backslashes % 2 == 0) {
            cursor = closingPos;
            break;
        }

        cursor = closingPos + 1;
    }

    std.debug.assert(cursor < src.len);
    std.debug.assert(cursor > l._cur);
    std.debug.assert(src[cursor] == '"');
    l._cur = @intCast(cursor + 1);
    return .string_value;
}

fn unclosedString(l: *LexerImpl) Token.Kind {
    return l.fatalError(error.UnclosedString, "Unclosed string", .{});
}
fn unclosedBlockString(l: *LexerImpl) Token.Kind {
    return l.fatalError(error.UnclosedBlockString, "Unclosed block string", .{});
}
