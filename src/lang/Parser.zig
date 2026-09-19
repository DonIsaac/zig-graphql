const Parser = @This();

const std = @import("std");
const Ast = @import("Ast.zig");
const Diagnostic = @import("../Diagnostic.zig");
const Allocator = std.mem.Allocator;

const ParserImpl = @import("Parser/ParserImpl.zig");
const document = @import("Parser/document.zig");

// lexer: Lexer,
_impl: ParserImpl,

pub const Error = ParserImpl.Error;
pub const Options = ParserImpl.Options; // TODO: use

/// Create a new Parser.
///
/// Initializing a Parser does nothing until a document is parsed.
///
/// Caller maintains ownership over `source`.
pub inline fn init(allocator: Allocator, source: []const u8) Parser {
    return .{ ._impl = ParserImpl.init(allocator, source) };
}

pub fn parseDocument(self: *Parser) Parser.Error!Ast.Document {
    return document.parseDocument(&self._impl, false);
}

pub fn parseExecutableDocument(self: *Parser) Parser.Error!Ast.Document {
    return document.parseDocument(&self._impl, true);
}

pub fn errors(self: *Parser) []const Diagnostic {
    return self._impl.errors();
}

// pub fn parse(self: *Parser) !Ast.Document {
//     return .{};
// }

test {
    std.testing.refAllDecls(ParserImpl);
}

test Parser {
    const query =
        \\query AuthorsWithBooks {
        \\  getAuthors(minBooks: 1) {
        \\    id,
        \\    name,
        \\    books {
        \\      title
        \\      description
        \\    }
        \\  }
        \\}
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(), query);
    const doc = parser.parseDocument() catch |e| {
        for (parser.errors()) |err| {
            std.debug.print("{s}\n", .{err.message});
        }
        return e;
    };
    try std.testing.expectEqual(1, doc.definitions.len);
}
