const Lexer = @This();

pub const Token = @import("Lexer/Token.zig");
const tables = @import("Lexer/tables.zig");

errors: std.ArrayListUnmanaged(Diagnostic),
allocator: Allocator,
source: []const u8,
/// Current token being lexed
tok: Token,
/// Current position in the source text
curr: u32,

pub fn init(allocator: Allocator, source: []const u8) Lexer {
    // SAFETY: source must be addressable by u32 offsets
    assert(source.len <= std.math.maxInt(u32));
    return .{
        .allocator = allocator,
        .errors = .{},
        .source = source,
        .tok = Token.empty,
        .curr = 0,
    };
}

pub fn next(self: *Lexer) !?Token {
    if (self.curr >= self.source.len) {
        @branchHint(.unlikely);
        return null;
    }

    const byte = self.currByte();
    const handler = tables.ASCII_TABLE[byte];
    @call(.auto, handler, .{ self, byte });
    return self.endTok();
    // handler(self, byte);
}

// =============================================================================

/// Start a new token
///
/// - current token gets reset to a new token of `kind` starting at the current position.
/// - current token is invalid until `endTok` is called.
pub fn startTok(self: *Lexer, kind: ?Token.Kind) callconv(util.callconv_inline) void {
    self.tok.kind = kind orelse .undetermined;
    // intentionally invalid span. `tok` only becomes valid after `endTok` is called.
    self.tok.span = .{ .start = self.curr, .end = undefined };
}

/// End the current token
pub fn endTok(self: *Lexer) callconv(util.callconv_inline) Token {
    self.tok.span.end = self.curr;
    return self.tok;
}

// ============================== LEXING UTILITIES =============================

pub inline fn span(self: *Lexer) Span {
    return Span{ .start = self.tok.span.start, .end = self.curr };
}

/// Get the current byte in the source.
/// 
/// ## Panics
/// If the Lexer has reached the end of the source file.
pub inline fn currByte(self: *Lexer) u8 {
    return self.source[self.curr];
}

/// Peek the next byte in the source. Returns `null` if the end of the source is reached.
pub inline fn peek(self: *Lexer) ?u8 {
    const next_pos = self.curr + 1;
    return if (next_pos >= self.source.len) null else self.source[next_pos];
}


pub inline fn bump(self: *Lexer) void {
    util.debugAssert(self.curr < self.source.len);
    self.curr += 1;
}

// pub fn expectUnsafe(self: *Lexer, byte: u8) callconv(util.callconv_inline) void {
//     assert(self.curr[])
// } 

// ============================== ERROR HANDLING ===============================

/// Record an unrecoverable error. Lexing will stop immediately.
pub fn fatalError(
    self: *Lexer,
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
    self.curr = @intCast(self.source.len);
    if (util.is_debug) {
        self.tok = Token.empty;
    }
}

/// Record a recoverable error.
///
/// Use `fatalError` instead if the error is unrecoverable.
pub fn err(
    self: *Lexer,
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

const std = @import("std");
const Diagnostic = @import("Diagnostic.zig");
const Span = @import("Span.zig");
const util = @import("util.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

test {
    _ = @import("Lexer/test/Lexer.test.zig");
}
