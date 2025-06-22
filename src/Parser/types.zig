const ParserImpl = @import("ParserImpl.zig");
const Ast = @import("../Ast.zig");

pub fn parseNamedType(self: *ParserImpl) !Ast.Type {
    return self.parseName();
}
/// `[Type]`
pub fn parseListType(self: *ParserImpl) !Ast.Type.List {
    try self.expect(.l_bracket);
    const start = self.startSpan();
    const ty = try self.parseType();
    try self.expect(.r_bracket);
    const span = self.endSpan(start);

    return Ast.Type.List{ .type = ty, .span = span };
}

pub fn parseNonNullType(self: *ParserImpl) !Ast.Type.NonNull {
    _ = self;
    @panic("todo");
}
