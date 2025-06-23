//! ## TODO
//! - [ ] make error recovery optional
//!     - GraphQL servers ant to abort at the first syntax error.
//!     - Tooling wants recovery for better DX
const ParserImpl = @This();

const std = @import("std");
const util = @import("../util.zig");
const Lexer = @import("../Lexer.zig");
const Token = Lexer.Token;
const Ast = @import("../Ast.zig");
const Span = @import("../Span.zig");
const Diagnostic = @import("../Diagnostic.zig");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const values = @import("values.zig");
const expressions = @import("expressions.zig");
const AstBuilder = @import("AstBuilder.zig");

lexer: Lexer,
/// previously peeked token
lookahead: ?Lexer.Token = null,
cur: Lexer.Token,
/// End offset of previous token
prev_tok_end: u32,
options: Options,
panicked: bool,
ast: AstBuilder,

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
    OutOfMemory,
    UnexpectedByte,
};

pub fn ParserFn(T: type) type {
    return fn (p: *ParserImpl) ParserImpl.Error!T;
}

pub fn init(allocator_: Allocator, source_: []const u8) ParserImpl {
    // SAFETY: initialized at the start of parsing, and only read while parsing.
    var p = ParserImpl{ .lexer = Lexer.init(allocator_, source_), .cur = Token.empty, .prev_tok_end = 0, .options = .{}, .panicked = false, .ast = undefined };
    p.ast = AstBuilder.init(&p);
    return p;
}

// pub fn parseDocument(self: *ParserImpl) !Ast.Document {
//     var definitions = try std.ArrayListUnmanaged(Ast.Definition).initCapacity(self.allocator(), 1);
//     _ = &definitions;
//     @panic("todo");
// }
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
pub fn eat(self: *ParserImpl, comptime expected: Token.Kind) !?Token {
    if (self.at(expected)) |tok| {
        try self.bump();
        return tok;
    }
    return null;
}

/// Ensures the current token matches `expected` and advances to the next token.
pub inline fn expect(self: *ParserImpl, expected: Lexer.Token.Kind) !void {
    try self.expectWithoutAdvance(expected);
    try self.bump();
}

/// Errors if current token is not `expected`. Does not advance the current token.
pub fn expectWithoutAdvance(self: *ParserImpl, comptime expected: Token.Kind) !void {
    _ = self.at(expected) orelse {
        @branchHint(.cold);
        self.lexer._impl.fatalError("Expected {s}, got {s}", .{ @tagName(expected), @tagName(self.cur.kind) });
        return error.UnexpectedToken;
    };
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
        @branchHint(.cold);
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
        @branchHint(.cold);
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

/// Consume the next token. Current token is updated. Returns the new, now current, token.
pub fn nextToken(self: *ParserImpl) !?Lexer.Token {
    self.prev_tok_end = self.cur.span.end;

    if (self.lookahead) |tok| {
        self.cur = tok;
        self.lookahead = null;
        return tok;
    }

    const tok = try self.lexer.next() orelse {
        @branchHint(.unlikely);
        return null;
    };
    self.cur = tok;
    return tok;
}

pub inline fn startSpan(self: *const ParserImpl) u32 {
    return self.cur.span.start;
}

pub inline fn endSpan(self: *const ParserImpl, start: u32) Span {
    return .{ .start = start, .end = self.cur.span.end };
}

pub inline fn source(self: *const ParserImpl) []const u8 {
    return self.lexer.source();
}

// =========================== ALLOCATION ============================

// pub inline fn allocator(self: *const ParserImpl) Allocator {
//     return self.lexer._impl.allocator;
// }
// pub fn create(self: *const ParserImpl, ast_node: anytype) Allocator.Error!*@TypeOf(ast_node) {
//     const T = @TypeOf(ast_node);
//     const ptr: *T = try self.allocator().create(T);
//     ptr.* = ast_node;
//     return ptr;
// }
// pub inline fn list(
//     self: *const ParserImpl,
//     comptime T: type,
//     comptime capacity: usize,
// ) Allocator.Error!std.ArrayList(T) {
//     return std.ArrayList(T).initCapacity(self.allocator(), capacity);
// }

// =========================== COMMON PARSE METHODS ============================

// NOTE: do not use `pub usingnamespace`, i'd like incremental compilation tyvm
pub const parseName = expressions.parseName;
pub const parseType = types.parseType;
pub const parseValue = values.parseValue;
pub const parseListOf = expressions.parseListOf;

// =============================================================================

pub fn errors(self: *const ParserImpl) []const Diagnostic {
    return self.lexer._impl.errors.items;
}
/// Report a non fatal error.
pub fn report(self: *ParserImpl, diagnostic: Diagnostic) void {
    self.lexer._impl.errors.append(self.lexer._impl.allocator, diagnostic) catch unreachable;
}
pub fn errAtCurr(self: *const ParserImpl, message: []const u8) Diagnostic {
    return Diagnostic{ .message = message, .span = self.cur.span };
}

pub fn unexpectedToken(self: *ParserImpl) ParserImpl.Error {
    @branchHint(.cold);
    const tok = self.cur;
    const msg = std.fmt.allocPrint(self.lexer._impl.allocator, "Unexpected token: '{s}'", .{@tagName(tok.kind)}) catch unreachable;
    self.report(Diagnostic{ .span = tok.span, .message = msg });
    return error.UnexpectedToken;
}

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(types);
}
