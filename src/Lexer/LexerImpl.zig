const LexerImpl = @This();

const std = @import("std");
const Diagnostic = @import("../Diagnostic.zig");
const Span = @import("../Span.zig");
const util = @import("../util.zig");

const Token = @import("Token.zig");
const tables = @import("tables.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

errors: std.ArrayListUnmanaged(Diagnostic),
allocator: Allocator,
source: []const u8,
/// Current token being lexed
tok: Token,
/// Current position in the source text
_cur: u32,

pub fn init(allocator: Allocator, source: []const u8) LexerImpl {
    // SAFETY: source must be addressable by u32 offsets
    assert(source.len <= std.math.maxInt(u32));
    return .{
        .allocator = allocator,
        .errors = .{},
        .source = source,
        .tok = Token.empty,
        ._cur = 0,
    };
}

pub const Ignore = enum(u2) {
    None,
    Whitespace,
    Ignored,
    inline fn lt(self: Ignore, other: Ignore) bool {
        return @intFromEnum(self) < @intFromEnum(other);
    }
    inline fn gte(self: Ignore, other: Ignore) bool {
        return @intFromEnum(self) >= @intFromEnum(other);
    }
};

// pub fn next(self: *LexerImpl) !?Token {
//     return self.nextImpl(.Whitespace);
// }
// pub fn nextNoSkip(self: *LexerImpl) !?Token {
//     return self.nextImpl(.None);
// }

pub fn next(self: *LexerImpl, comptime skip_ignored: Ignore) !?Token {
    while (self.curr()) |byte| {
        @branchHint(.likely);
        self.startTok();
        switch (tables.handleASCIIByte(self, byte)) {
            .undetermined => {
                @branchHint(.cold);
                _ = self.endTok(.undetermined);
                return error.UnexpectedByte;
            },
            .whitespace, .line_terminator => |kind| if (skip_ignored.gte(.Whitespace)) continue else {
                return self.endTok(kind);
            },
            .comma, .comment, .block_comment => |kind| if (skip_ignored == .Ignored) continue else {
                return self.endTok(kind);
            },
            else => |kind| {
                util.debugAssert(!kind.isIgnored());
                return self.endTok(kind);
            },
        }
    }
    return null;
}

// =============================================================================

/// Start a new token
///
/// - current token gets reset to a new token of `kind` starting at the current position.
/// - current token is invalid until `endTok` is called.
pub fn startTok(self: *LexerImpl) callconv(util.callconv_inline) void {
    // intentionally invalid token. `tok` only becomes valid after `endTok` is called.
    self.tok = .{
        .kind = undefined,
        .span = .{ .start = self._cur, .end = undefined },
    };
}

/// End the current token
pub fn endTok(self: *LexerImpl, kind: Token.Kind) callconv(util.callconv_inline) Token {
    self.tok.kind = kind;
    self.tok.span.end = self._cur;
    return self.tok;
}

/// Source text remaining after current position.
pub inline fn remaining(self: *const LexerImpl) []const u8 {
    return self.source[self._cur..];
}

// ============================== LEXING UTILITIES =============================

pub inline fn span(self: *LexerImpl) Span {
    return Span{ .start = self.tok.span.start, .end = self._cur };
}

/// Get the current byte in the source.
///
/// ## Panics
/// If the LexerImpl has reached the end of the source file.
pub inline fn curr(self: *const LexerImpl) ?u8 {
    if (self._cur >= self.source.len) {
        @branchHint(.unlikely);
        return null;
    }
    return self.source[self._cur];
}

/// Peek the next byte in the source. Returns `null` if the end of the source is reached.
pub inline fn peek(self: *LexerImpl) ?u8 {
    const next_pos = self._cur + 1;
    return if (next_pos >= self.source.len) null else self.source[next_pos];
}

/// Advance the current position by 1, regardless of the current byte.
pub inline fn bump(self: *LexerImpl) void {
    util.debugAssert(self._cur < self.source.len);
    self._cur += 1;
}

/// Advance the current position by 1. Panics if the current byte is not `byte`.
pub inline fn expect(self: *LexerImpl, byte: u8) void {
    assert(self.curr() == byte);
    self._cur += 1;
}

/// Advance the current position by `n`. Panics if the new position is out of bounds.
pub inline fn advanceBy(self: *LexerImpl, n: u32) void {
    assert(self._cur + n <= self.source.len);
    self._cur += n;
}

// pub fn expectUnsafe(self: *LexerImpl, byte: u8) callconv(util.callconv_inline) void {
//     assert(self._cur[])
// }

// ============================== ERROR HANDLING ===============================

/// Record an unrecoverable error. Lexing will stop immediately.
pub fn fatalError(
    self: *LexerImpl,
    comptime message: []const u8,
    args: anytype,
) callconv(util.callconv_inline) void {
    @branchHint(.cold);
    const msg: []const u8 = if (comptime args.len == 0)
        message
    else
        std.fmt.allocPrint(self.allocator, message, args) catch unreachable;

    const diag = Diagnostic.init(self.span(), msg);
    self.errors.append(self.allocator, diag) catch unreachable;
    self._cur = @intCast(self.source.len);
    if (util.is_debug) {
        self.tok = Token.empty;
    }
}

/// Record a recoverable error.
///
/// Use `fatalError` instead if the error is unrecoverable.
pub fn err(
    self: *LexerImpl,
    comptime message: []const u8,
    args: anytype,
) callconv(util.callconv_inline) void {
    @branchHint(.cold);

    const msg: []const u8 = if (comptime args.len == 0)
        message
    else
        std.fmt.allocPrint(self.allocator, message, args) catch unreachable;

    const diag = Diagnostic.init(self.span(), msg);
    self.errors.append(self.allocator, diag) catch unreachable;
}

pub const Error = error{
    UnexpectedByte,
    OutOfMemory,
};
