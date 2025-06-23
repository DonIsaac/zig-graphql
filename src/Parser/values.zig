const ParserImpl = @import("ParserImpl.zig");
const Ast = @import("../Ast.zig");

pub fn parseValue(p: *ParserImpl) ParserImpl.Error!Ast.Value {
    _ = &p;
    @panic("todo");
}
