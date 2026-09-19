const Ast = @import("../Ast.zig");
const ParserImpl = @import("./ParserImpl.zig");
const ParserFn = ParserImpl.ParserFn;
const Token = @import("../Lexer.zig").Token;

pub fn parseName(self: *ParserImpl) !Ast.Name {
    const start = self.startSpan();
    try self.expect(.name); // TODO: some keywords can be valid names given the context
    const span = self.endSpan(start);
    return Ast.Name{
        .value = span.slice(self.lexer.source()),
        .pos = span.offset(.Start),
    };
}

pub fn parseListOf(
    comptime Node: type,
    comptime Fn: ParserFn(Node),
    comptime first_token: []const Token.Kind,
) ParserFn([]Node) {
    return struct {
        pub fn parseList(p: *ParserImpl) ![]Node {
            var nodes = try p.ast.list(Node, 1);
            while (p.atAny(first_token)) {
                const node = try Fn(p);
                try nodes.append(p.allocator(), node);
                _ = try p.eat(.comma);
            }

            if (p.options.lossless) {
                // fully reclaims unused memory if resizing isnt possible
                return nodes.toOwnedSlice(p.allocator());
            }

            // attempt to resize the list's buffer in-place. If resizing would require
            // a reallocation + copy, we'll leak the memory
            _ = p.allocator().resize(nodes.allocatedSlice(), nodes.items.len);
            return nodes.items;
        }
    }.parseList;
}
