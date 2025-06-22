const ParserImpl = @This();

const std = @import("std");
const Lexer = @import("../Lexer.zig");
const Ast = @import("../Ast.zig");
const Span = @import("../Span.zig");
const Diagnostic = @import("../Diagnostic.zig");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");

lexer: Lexer,
/// previously peeked token
lookahead: ?Lexer.Token = null,
cur: Lexer.Token,

pub const Error = error{
    UnexpectedEOF,
    UnexpectedToken,
    OutOfMemory,
    UnexpectedByte,
};

pub fn init(allocator: Allocator, source: []const u8) ParserImpl {
    // SAFETY: initialized at the start of parsing, and only read while parsing.
    return .{
        .lexer = Lexer.init(allocator, source),
        .cur = undefined,
    };
}

pub fn errors(self: *const ParserImpl) []const Diagnostic {
    return self.lexer._impl.errors.items;
}

/// Get the next token without consuming it.
pub fn peek(self: *ParserImpl) !?Lexer.Token {
    return self.lookahead orelse {
        self.lookahead = try self.lexer.next();
        return self.lookahead;
    };
}

pub fn bump(self: *ParserImpl) !void {
    _ = try self.nextToken();
}
/// Consume the next token if it matches the expected token. No-op if it doesn't.
pub fn eat(self: *ParserImpl, expected: Lexer.Token.Kind) !void {
    if (try self.peek()) |tok| {
        if (tok.kind == expected) {
            _ = try self.nextToken();
        }
    }
}

/// Ensures the current token matches `expected` and moves to the next token.
pub inline fn expect(self: *ParserImpl, expected: Lexer.Token.Kind) !void {
    try self.expectWithoutAdvance(expected);
    try self.bump();
}

/// Errors if current token is not `expected`. Does not advance the current token.
pub fn expectWithoutAdvance(self: *ParserImpl, expected: Lexer.Token.Kind) !void {
    if (!self.at(expected)) {
        @branchHint(.cold);
        self.lexer._impl.fatalError("Expected {s}, got {s}", .{ @tagName(expected), @tagName(self.cur.kind) });
        return error.UnexpectedToken;
    }
}

pub inline fn at(self: *const ParserImpl, expected: Lexer.Token.Kind) bool {
    return self.cur.kind == expected;
}

/// Consume the next token. Current token is updated.
pub fn nextToken(self: *ParserImpl) !?Lexer.Token {
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

pub fn alloc(self: *ParserImpl, ast_node: anytype) Allocator.Error!*@TypeOf(ast_node) {
    const T = @TypeOf(ast_node);
    const ptr: *T = try self.lexer._impl.allocator.create(T);
    ptr.* = ast_node;
    return ptr;
}

fn parseDocument(self: *ParserImpl) !Ast.Document {
    var definitions = try std.ArrayListUnmanaged(Ast.Definition).initCapacity(self.allocator, 1);
    _ = &definitions;
    @panic("todo");
}

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(types);
}
