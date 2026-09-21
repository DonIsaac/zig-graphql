// zlint-disable suppressed-errors -- parser helpers assume allocations succeed for performance reasons
//! ## TODO
//! - [ ] make error recovery optional
//!     - GraphQL servers ant to abort at the first syntax error.
//!     - Tooling wants recovery for better DX
//! - [ ] Many productions that take at least 1 item are not yet checking for empty lists.
const ParserImpl = @This();

const std = @import("std");
const util = @import("../../util.zig");
const Lexer = @import("../Lexer.zig");
const Token = Lexer.Token;
const Span = @import("../../Span.zig");
const Diagnostic = @import("../../Diagnostic.zig");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const values = @import("values.zig");
const expressions = @import("expressions.zig");
const Ast = @import("../Ast.zig");

options: Options,
lexer: Lexer,
/// previously peeked token
lookahead: ?Lexer.Token = null,
cur: Lexer.Token,
/// End offset of previous token
prev_tok_end: u32,
panicked: bool,
ast: Ast.Builder,
comments: std.ArrayListUnmanaged(Lexer.Token),

pub const Options = struct {
    /// Do not leak memory when constructing Ast nodes. Less memory
    /// is wasted at the cost of cpu cycles.
    ///
    /// It is recommended to set this to `true` when not using an `ArenaAllocator`.
    lossless: bool = false,
};
pub const Error = error{
    UnexpectedEOF,
    UnexpectedToken,
    UnclosedString,
    UnclosedBlockString,
    // OutOfMemory,
    // UnexpectedByte,
} || Lexer.Error || Allocator.Error;

pub fn Fn(T: type) type {
    return fn (p: *ParserImpl) ParserImpl.Error!T;
}

pub fn init(allocator_: Allocator, source_: []const u8) ParserImpl {
    var p = ParserImpl{
        .lexer = Lexer.init(allocator_, source_),
        .cur = Token.empty,
        .prev_tok_end = 0,
        .options = .{},
        .panicked = false,
        // SAFETY: initialized below
        .ast = undefined,
        .comments = .empty,
    };
    p.ast = .init(&p);
    return p;
}

pub fn deinit(self: *ParserImpl) void {
    self.lexer.deinit();
    self.comments.deinit(self.lexer._impl.allocator);
    self.* = undefined;
}

// =============================================================================

/// Get the next token without consuming it.
pub fn peek(self: *ParserImpl) !?Lexer.Token {
    return self.lookahead orelse {
        self.lookahead = try self.lexer.next();
        return self.lookahead;
    };
}

pub fn bump(self: *ParserImpl) ParserImpl.Error!void {
    _ = try self.nextToken();
}

/// Similar to `.at`, but consumes and returns the current token on match.
pub fn eat(self: *ParserImpl, comptime expected: Token.Kind) Error!?Token {
    if (self.at(expected)) |tok| {
        try self.bump();
        return tok;
    }
    return null;
}

/// Ensures the current token matches `expected` and advances to the next token.
pub inline fn expect(self: *ParserImpl, comptime expected: Lexer.Token.Kind) Error!Token {
    const tok = try self.expectWithoutAdvance(expected);
    try self.bump();
    return tok;
}

/// Errors if current token is not `expected`. Does not advance the current token.
pub fn expectWithoutAdvance(self: *ParserImpl, comptime expected: Token.Kind) !Token {
    return self.at(expected) orelse self.expectedToken(@tagName(expected));
}

/// Consumes the current token, invoking Illegal Behavior if it
/// doesn't match `expected`.
///
/// Whereas `expect` is used to report syntax errors that the parser must handle
/// during normal operations, failures by `assert` indicate a bug in the program.
///
/// Calling this method when the current token is not `expected` is
/// safety-checked Illegal Behavior.
pub inline fn assert(self: *ParserImpl, comptime expected: Lexer.Token.Kind) !void {
    self.assertWithoutAdvance(expected);
    return self.bump();
}

/// Panics if the current token's kind differs from the expected kind.
///
/// Whereas `expect` is used to report syntax errors that the parser must handle
/// during normal operations, failures by `assert` indicate a bug in the program.
///
/// Calling this method when the current token is not `expected` is
/// safety-checked Illegal Behavior.
pub inline fn assertWithoutAdvance(self: *ParserImpl, comptime expected: Lexer.Token.Kind) void {
    if (comptime !util.assert_enabled) return;
    if (self.at(expected) == null) {
        std.debug.panic(
            "Assertion failed: unexpected current token at offset {d}.\n\tExpected: {s}\n\tGot: {s}\n",
            .{ self.cur.span.start, @tagName(expected), @tagName(self.cur.kind) },
        );
    }
}
/// Triggers safety-checked Illegal Behavior if the current token is
/// `unexpected`.
pub inline fn assertNotWithoutAdvance(self: *ParserImpl, comptime unexpected: Lexer.Token.Kind) void {
    if (comptime !util.assert_enabled) return;
    if (self.at(unexpected)) |tok| {
        std.debug.panic(
            "Assertion failed: Expected {any} token to have already been consumed.",
            .{tok},
        );
    }
}

/// Returns the current token if it has the expected kind.
///
/// TODO: check ReleaseFast assembly, make sure `p.curr() ==/!= null` gets elided
/// to the same code as `self.cur.kind == expected`
pub inline fn at(
    self: *const ParserImpl,
    comptime expected: Token.Kind,
) ?Token {
    return if (self.cur.kind == expected) self.cur else null;
}

/// Returns `true` if current token is any of the expected kinds.
pub inline fn atAny(
    self: *const ParserImpl,
    comptime expected: []const Token.Kind,
) bool {
    comptime std.debug.assert(expected.len > 0);
    inline for (expected) |e| {
        if (self.at(e)) |_| return true;
    } else return false;
}

/// Consume the next token. Current token is updated. Returns the new, now
/// current, token, or `null` once the source has been exhausted.
///
/// The current token becomes `.eof` when this returns `null`, so `at`,
/// `expect`, and friends never see a stale token past the end of the source.
pub fn nextToken(self: *ParserImpl) !?Lexer.Token {
    self.prev_tok_end = self.cur.span.end;

    if (self.lookahead) |tok| {
        self.cur = tok;
        self.lookahead = null;
        return tok;
    }

    const tok: Lexer.Token = t: {
        while (true) {
            const next_tok = try self.lexer.next() orelse {
                @branchHint(.unlikely);
                self.cur = self.eofToken();
                return null;
            };
            switch (next_tok.kind) {
                .comment => try self.comments.append(self.lexer._impl.allocator, next_tok),
                else => {
                    @branchHint(.likely);
                    break :t next_tok;
                },
            }
        }
        unreachable;
    };
    self.cur = tok;
    return tok;
}

/// Returns `true` once every token in the source has been consumed.
pub inline fn atEof(self: *const ParserImpl) bool {
    return self.at(.eof) != null;
}

/// A zero-width token sitting at the end of the source.
fn eofToken(self: *const ParserImpl) Token {
    const end: u32 = @intCast(self.source().len);
    return .{ .kind = .eof, .span = .{ .start = end, .end = end } };
}

pub inline fn startSpan(self: *const ParserImpl) u32 {
    return self.cur.span.start;
}

pub inline fn endSpan(self: *const ParserImpl, start: u32) Span {
    return .{ .start = start, .end = self.prev_tok_end };
}

pub inline fn source(self: *const ParserImpl) []const u8 {
    return self.lexer.source();
}

// =========================== ALLOCATION ============================

pub inline fn allocator(self: *const ParserImpl) Allocator {
    return self.lexer._impl.allocator;
}

// =========================== COMMON PARSE METHODS ============================

pub const parseName = expressions.parseName;
pub const parseType = types.parseType;
pub const parseValue = values.parseValue;
pub const parseStringValue = values.parseStringValue;
pub const parseListOf = expressions.parseListOf;

// =============================================================================

pub fn errors(self: *ParserImpl) []Diagnostic {
    return self.lexer._impl.errors.items;
}

/// Report a non fatal error.
pub fn report(self: *ParserImpl, diagnostic: Diagnostic) void {
    self.lexer._impl.errors.append(self.lexer._impl.allocator, diagnostic) catch unreachable;
}

pub fn reportFatal(self: *ParserImpl, err: Error, diagnostic: Diagnostic) Error {
    self.report(diagnostic);
    self.panicked = true;
    self.lexer._impl._cur = @intCast(self.lexer._impl.source.len);
    return err;
}

pub fn errAtCurr(self: *const ParserImpl, message: []const u8) Diagnostic {
    return Diagnostic{ .message = message, .span = self.cur.span };
}

pub fn unexpectedToken(self: *ParserImpl) ParserImpl.Error {
    @branchHint(.cold);
    const tok = self.cur;
    const msg = std.fmt.allocPrint(
        self.lexer._impl.allocator,
        "Unexpected token: '{s}'",
        .{@tagName(tok.kind)},
    ) catch unreachable;
    self.report(Diagnostic{ .span = tok.span, .message = msg });
    return error.UnexpectedToken;
}

pub fn expectedToken(self: *ParserImpl, comptime expected: []const u8) ParserImpl.Error {
    @branchHint(.cold);
    const tok = self.cur;
    const msg = std.fmt.allocPrint(
        self.lexer._impl.allocator,
        "Expected " ++ expected ++ ", got '{s}'",
        .{@tagName(tok.kind)},
    ) catch unreachable;

    return self.reportFatal(error.UnexpectedToken, Diagnostic{ .span = tok.span, .message = msg });
}

test {
    std.testing.refAllDecls(ParserImpl);
    std.testing.refAllDecls(types);
}
