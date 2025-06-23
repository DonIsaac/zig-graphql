const std = @import("std");
const util = @import("../util.zig");
const Token = @import("../Lexer.zig").Token;
const ParserImpl = @import("ParserImpl.zig");
const Ast = @import("../Ast.zig");
const Span = @import("../Span.zig");

const definitions = @import("definitions.zig");

/// `Document : Definition+`
pub fn parseDocument(p: *ParserImpl) !Ast.Document {
    // p.bump();
    const start = p.startSpan();
    var defs = try p.ast.list(Ast.Definition, 1);
    while (try p.nextToken()) |t| {
        util.debugAssert(t.eql(p.cur));
        const def: Ast.Definition = try definitions.parseDefinition(p);
        try defs.append(def);
    }

    const span = p.endSpan(start);
    _ = p.ast.allocator().resize(defs.allocatedSlice(), defs.items.len);
    // TODO: report empty defs
    return Ast.Document{ .definitions = defs.items, .span = span };
}
