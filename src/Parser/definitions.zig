const std = @import("std");
const ParserImpl = @import("ParserImpl.zig");
const Ast = @import("../Ast.zig");
const Token = @import("../Lexer.zig").Token;
const Span = @import("../Span.zig");
const diagnostics = @import("diagnostics.zig");

pub fn parseExecutableDefinition(
    p: *ParserImpl,
) !Ast.ExecutableDefinition {
    // return switch (p.cur.kind) {
    //     .kw_query, .kw_mutation, .kw_subscription => .{ .operation = try parseOperationDefinition(p) },
    //     .kw_fragment => .{ .fragment = try parseFragmentDefinition(p) },
    //     else => p.unexpectedToken(),
    // };
    return if (p.at(.kw_fragment))
        .{ .fragment = try parseFragmentDefinition(p) }
    else
        .{ .operation = try parseOperationDefinition(p) };
}

///    OperationDefinition :
///        OperationType Name? VariablesDefinition? Directives? SelectionSet
///        SelectionSet
fn parseOperationDefinition(p: *ParserImpl) !Ast.OperationDefinition {
    const start = p.startSpan();
    const op: Ast.OperationType = switch (p.cur.kind) {
        .kw_query => .query,
        .kw_mutation => .mutation,
        .kw_subscription => .subscription,
        else => return parseSelectionSet(p),
    };
    p.bump();
    const name: ?Ast.Name = if (p.at(.name)) try p.parseName() else null;
    const vars: ?Ast.VariablesDefinition = try parseVariablesDefinition(p);
    const directives: ?Ast.Directives = try parseDirectives(p);
    const selection_set: Ast.SelectionSet = try parseSelectionSet(p);

    _ = start;
    _ = op;
    _ = name;
    _ = vars;
    _ = directives;
    _ = selection_set;
    @panic("todo");
}

///    fragment FragmentName TypeCondition Directives?
fn parseFragmentDefinition(p: *ParserImpl) !Ast.FragmentDefinition {
    const start = p.startSpan();
    try p.assert(.kw_fragment);
    const name: Ast.Name = if (p.at(.kw_on)) |t| on: {
        @branchHint(.unlikely);
        p.report(.{
            .message = "Fragment is missing a name",
            .span = .{ .start = start, .end = t.span.end },
        });
        // recover
        const name_span = Span.sized(p.prev_tok_end, 0);
        break :on .{ .name = "", .span = name_span };
    } else try parseFragmentName(p, true);
    const type_cond = try parseTypeCondition(p);
    const directives = try parseDirectives(p);
    _ = name;
    _ = type_cond;
    _ = directives;
    @panic("todo");
}

////    FragmentName: _Name_ but not `on`
fn parseFragmentName(
    p: *ParserImpl,
    /// How to treat `on` tokens
    /// - `true`: report a syntax error
    /// - `false`: panic
    comptime handle_kw_on: bool,
) !Ast.Name {
    if (comptime handle_kw_on) {
        if (p.at(.kw_on)) {
            @branchHint(.unlikely);
            p.report(diagnostics.fragmentNameCannotBeOn(p.cur));
        }
    } else {
        std.debug.assert(!p.at(.kw_on));
    }
    const slice = p.cur.span.slice(p.lexer.source());
    try p.bump();
    return Ast.Name{ .pos = p.cur.span.offset(.Start), .value = slice };
}
const parseSelectionSet = ParserImpl.parseListOf(Ast.Selection, parseSelection, &[_]Token.Kind{.name});
fn parseSelection(p: *ParserImpl) !Ast.Selection {
    _ = &p;
    @panic("todo");
}

const parseDirectives = ParserImpl.parseListOf(Ast.Directive, parseDirective, &[_]Token.Kind{.at});
fn parseDirective(p: *ParserImpl) !Ast.Directive {
    _ = &p;
    @panic("todo");
}

fn parseVariablesDefinition(p: *ParserImpl) !Ast.FragmentDefinition {
    _ = &p;
    @panic("todo");
}

// todo: Ast.TypeCondition
fn parseTypeCondition(p: *ParserImpl) !Ast.Name {
    _ = &p;
    @panic("todo");
}
