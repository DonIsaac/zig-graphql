const std = @import("std");
const Ast = @import("../Ast.zig");
const ParserImpl = @import("./ParserImpl.zig");
const Token = @import("../Lexer.zig").Token;

const diagnostics = @import("diagnostics.zig");

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

/// `Arguments[Const] : `(` Argument[?Const]+ `)`
pub fn parseArguments(p: *ParserImpl, comptime opt: bool, comptime @"const": bool) !Ast.Argument.List {
    const start = p.startSpan();

    _ = if (comptime opt)
        try p.eat(.l_paren) orelse return Ast.Argument.List.empty
    else
        try p.expect(.l_paren);

    const args = try parseArgumentList(p, @"const");
    _ = try p.expect(.r_paren);

    return Ast.Argument.List{
        .args = args,
        .span = p.endSpan(start),
    };
}

/// `Argument[Const] : Name : Value[?Const]`
fn parseArgument(p: *ParserImpl, comptime @"const": bool) !Ast.Argument {
    const start = p.startSpan();

    // accidental `{ user($id: 123) }`
    if (try p.eat(.dollar)) |dollar| {
        // TODO: configurable error recovery
        p.report(diagnostics.argumentCannotBeVariable(dollar));
    }

    const name = try p.parseName();
    _ = try p.expect(.colon);
    const value = try p.parseValue(@"const");

    return Ast.Argument{
        .name = name,
        .value = value,
        .span = p.endSpan(start),
    };
}

fn parseArgumentList(p: *ParserImpl, comptime @"const": bool) ![]Ast.Argument {
    const Wrapper = struct {
        pub fn parse(p_: *ParserImpl) !Ast.Argument {
            return parseArgument(p_, @"const");
        }
    };

    const parseArgList = parseListOf(Ast.Argument, Wrapper.parse, &[_]Token.Kind{.name});
    return parseArgList(p);
}

/// `Directives[Const] : Directive[?Const]+`
fn DirectiveListParser(comptime @"const": bool) ParserImpl.Fn([]Ast.Directive) {
    const Wrapper = struct {
        pub fn parse(p: *ParserImpl) ParserImpl.Error!Ast.Directive {
            return parseDirective(p, @"const");
        }
    };
    return ParserImpl.parseListOf(Ast.Directive, Wrapper.parse, &[_]Token.Kind{.at});
}

/// `Directives : Directive+`
pub const parseDirectives = DirectiveListParser(false);

/// `Directives[Const] : Directive[Const]+`
pub const parseConstDirectives = DirectiveListParser(true);

/// `Directive[Const] : @ Name Arguments[?Const]?`
fn parseDirective(p: *ParserImpl, comptime @"const": bool) ParserImpl.Error!Ast.Directive {
    const start = p.startSpan();
    try p.assert(.at);

    const name = try p.parseName();
    const arguments: ?[]Ast.Argument = if (p.at(.l_paren)) |_|
        (try parseArguments(p, false, @"const")).args
    else
        null;

    return Ast.Directive{
        .name = name,
        .arguments = arguments,
        .span = p.endSpan(start),
    };
}

///     OperationType: one of
///         `query` `mutation` `subscription`
pub fn parseOperationType(p: *ParserImpl) !Ast.Operation.Type {
    const ty: Ast.Operation.Type = switch (p.cur.kind) {
        .kw_query => .query,
        .kw_mutation => .mutation,
        .kw_subscription => .subscription,
        else => return p.expectedToken("an operation type"),
    };
    try p.bump();
    return ty;
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
