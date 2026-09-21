const std = @import("std");
const Ast = @import("../Ast.zig");
const ParserImpl = @import("./ParserImpl.zig");
const Token = @import("../Lexer.zig").Token;

/// `Name : [_A-Za-z][_0-9A-Za-z]*`
///
/// Keywords are lexed apart from names to make parsing easier, but the spec has
/// no keywords: `type`, `input`, and friends are ordinary names wherever a name
/// is what's expected.
pub fn parseName(self: *ParserImpl) !Ast.Name {
    const tok = self.cur;
    if (!tok.kind.isName()) {
        @branchHint(.unlikely);
        return self.expectedToken("a name");
    }
    try self.bump();

    return Ast.Name{
        .value = tok.span.slice(self.lexer.source()),
        .pos = tok.span.offset(.Start),
    };
}

pub fn parseListOf(
    comptime Node: type,
    comptime Fn: ParserImpl.Fn(Node),
    comptime first_token: []const Token.Kind,
) ParserImpl.Fn([]Node) {
    // a list that starts at a name starts at a keyword too, since keywords are
    // spelled like names
    const names_start_a_node = comptime std.mem.indexOfScalar(Token.Kind, first_token, .name) != null;

    return struct {
        pub fn parseList(p: *ParserImpl) ![]Node {
            var nodes = try p.ast.list(Node, 1);
            while (p.atAny(first_token) or (names_start_a_node and p.cur.kind.isName())) {
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
