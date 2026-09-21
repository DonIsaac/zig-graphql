const util = @import("../../util.zig");
const ParserImpl = @import("ParserImpl.zig");
const Ast = @import("../Ast.zig");

const definitions = @import("definitions.zig");

/// `Document : Definition+`
/// `ExecutableDocument : ExecutableDefinition+`
pub fn parseDocument(p: *ParserImpl, comptime executable_only: bool) !Ast.Document {
    const start = p.startSpan();
    var defs = try p.ast.list(Ast.Document.Definition, 1);

    // prime `p.cur` with the first token. Every definition parser leaves it on
    // the first token of the *next* definition, so the loop must not advance.
    _ = try p.nextToken();
    while (!p.atEof()) {
        const def: Ast.Document.Definition = if (comptime executable_only)
            .{ .executable = try definitions.parseExecutableDefinition(p) }
        else
            try definitions.parseDefinition(p);
        try defs.append(p.allocator(), def);
    }

    const span = p.endSpan(start);
    // TODO: report empty defs
    return Ast.Document{ .definitions = try p.ast.intoSlice(Ast.Document.Definition, &defs), .span = span };
}
