const Ast = @import("../Ast.zig");
const ParserImpl = @import("./ParserImpl.zig");

pub fn parseName(self: *ParserImpl) !Ast.Name {
    const start = self.startSpan();
    try self.expect(.name); // TODO: some keywords can be valid names given the context
    const span = self.endSpan(start);
    return Ast.Name{ .value = span.slice(self.lexer.source()), .span = span };
}
