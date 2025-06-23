const util = @import("../../util.zig");
const ParserImpl = @import("ParserImpl.zig");
const Ast = @import("../Ast.zig");

const definitions = @import("definitions.zig");

/// `Document : Definition+`
/// `ExecutableDocument : ExecutableDefinition+`
pub fn parseDocument(p: *ParserImpl, comptime executable_only: bool) !Ast.Document {
    // p.bump();
    const start = p.startSpan();
    var defs = try p.ast.list(Ast.Definition, 1);
    while (try p.nextToken()) |t| {
        util.debugAssert(t.eql(p.cur));
        const def: Ast.Definition = if (comptime executable_only)
            .{ .executable = try definitions.parseExecutableDefinition(p) }
        else
            try definitions.parseDefinition(p);
        try defs.append(def);
    }

    const span = p.endSpan(start);
    _ = p.ast.allocator().resize(defs.allocatedSlice(), defs.items.len);
    // TODO: report empty defs
    return Ast.Document{ .definitions = defs.items, .span = span };
}
