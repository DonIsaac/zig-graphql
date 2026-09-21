const Ast = @import("../Ast.zig");
const ParserImpl = @import("./ParserImpl.zig");
const Token = @import("../Lexer.zig").Token;

pub fn parseName(self: *ParserImpl) !Ast.Name {
    const start = self.startSpan();
    _ = try self.expect(.name); // TODO: some keywords can be valid names given the context
    const span = self.endSpan(start);
    return Ast.Name{
        .value = span.slice(self.lexer.source()),
        .pos = span.offset(.Start),
    };
}

pub fn parseListOf(
    comptime Node: type,
    comptime Fn: ParserImpl.Fn(Node),
    comptime first_token: []const Token.Kind,
) ParserImpl.Fn([]Node) {
    return struct {
        pub fn parseList(p: *ParserImpl) ![]Node {
            var nodes = try p.ast.list(Node, 1);
            while (p.atAny(first_token)) {
                const node = try Fn(p);
                try nodes.append(p.allocator(), node);
                _ = try p.eat(.comma);
            }

            return p.ast.intoSlice(Node, &nodes);
        }
    }.parseList;
}

// pub fn parseOpt(
//     comptime Node: type,
//     comptime Fn: ParserImpl.Fn(Node),
// ) fn (p: *ParserImpl) error{OutOfMemory}!?Node {
//     return struct {
//         pub fn tryParse(p: *ParserImpl) !?Node {
//             const ckpt = p.lexer.checkpoint();
//             errdefer p.lexer.restore(ckpt);
//             return Fn(p) catch |e| switch (e) {
//                 error.OutOfMemory => |oom| return oom,
//                 else => {
//                     p.
//                 }
//             }

//         }
//     }.tryParse;
// }
