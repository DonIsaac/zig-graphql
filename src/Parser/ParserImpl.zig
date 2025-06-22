const ParserImpl = @This();

const std = @import("std");
const Lexer = @import("../Lexer.zig");
const Ast = @import("../Ast.zig");
const Span = @import("../Span.zig");
const Allocator = std.mem.Allocator;

lexer: Lexer,
/// previously peeked token
lookahead: ?Lexer.Token = null,
cur: Lexer.Token,

pub fn init(allocator: Allocator, source: []const u8) ParserImpl {
    // SAFETY: initialized at the start of parsing, and only read while parsing.
    return .{
        .lexer = Lexer.init(allocator, source),
        .cur = undefined,
    };
}

/// Get the next token without consuming it.
pub fn peek(self: *ParserImpl) !?Lexer.Token {
    return self.lookahead orelse {
        self.lookahead = try self.lexer.next();
        return self.lookahead;
    };
}

/// Consume the next token if it matches the expected token. No-op if it doesn't.
pub fn eat(self: *ParserImpl, expected: Lexer.Token.Kind) !void {
    if (try self.peek()) |tok| {
        if (tok.kind == expected) {
            _ = try self.nextToken();
        }
    }
}

/// Consume the next token and ensure it matches the expected token.
pub inline fn expect(self: *ParserImpl, expected: Lexer.Token.Kind) !void {
    self.cur = try self.nextToken() orelse return error.UnexpectedEOF;
    if (self.cur.kind != expected) {
        @branchHint(.cold);
        return error.UnexpectedToken;
    }
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

fn parseDocument(self: *ParserImpl) !Ast.Document {
    var definitions = try std.ArrayListUnmanaged(Ast.Definition).initCapacity(self.allocator, 1);
    _ = &definitions;
    @panic("todo");
}
