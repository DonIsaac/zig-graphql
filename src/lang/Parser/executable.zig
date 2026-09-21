const util = @import("../../util.zig");
const ParserImpl = @import("ParserImpl.zig");
const Ast = @import("../Ast.zig");
const Token = @import("../Lexer.zig").Token;

const expressions = @import("expressions.zig");
const values = @import("values.zig");
const types = @import("types.zig");
const diagnostics = @import("diagnostics.zig");

/// ## [2.2 Document - Executable Definition](https://spec.graphql.org/draft/#sec-Document)
///
///     ExecutableDefinition:
///         OperationDefinition
///         FragmentDefinition
pub fn parseExecutableDefinition(
    p: *ParserImpl,
) !Ast.Executable.Definition {
    return if (p.at(.kw_fragment)) |_|
        .{ .fragment = try parseFragmentDefinition(p) }
    else
        .{ .operation = try parseOperationDefinition(p) };
}

///    OperationDefinition :
///        OperationType Name? VariablesDefinition? Directives? SelectionSet
///        SelectionSet
fn parseOperationDefinition(p: *ParserImpl) !Ast.Operation.Definition {
    const start = p.startSpan();
    if (p.at(.l_curly)) |_| return p.ast.anonymousOperationDefinition(try parseSelectionSet(p, false));

    // TODO: maybe collapse with switch in `parseExecutableDefinition`. depends
    // on tradeoff: perf vs clarity-from-following-grammar-exactly
    const op = try expressions.parseOperationType(p);
    const name: ?Ast.Name = if (p.cur.kind.isName()) try p.parseName() else null;
    const vars: []Ast.Variable.Definition = try parseVariablesDefinition(p);
    const directives: []Ast.Directive = try expressions.parseDirectives(p);
    const selection_set: Ast.Selection.Set = try parseSelectionSet(p, true);

    return Ast.Operation.Definition{
        .operation_type = op,
        .name = name,
        .variable_definitions = vars,
        .directives = directives,
        .selection_set = selection_set,
        .span = p.endSpan(start),
    };
}

///    fragment FragmentName TypeCondition Directives? SelectionSet
fn parseFragmentDefinition(p: *ParserImpl) !Ast.Fragment.Definition {
    const start = p.startSpan();
    try p.assert(.kw_fragment);

    const name: Ast.Name = if (p.at(.kw_on)) |t| on: {
        @branchHint(.unlikely);
        p.report(.{
            .message = "Fragment is missing a name",
            .span = .{ .start = start, .end = t.span.end },
        });
        // recover
        break :on p.ast.name(p.endSpan(start));
    } else try parseFragmentName(p, true);

    const type_cond = try parseTypeCondition(p);
    const directives: []Ast.Directive = try expressions.parseDirectives(p);
    const selection_set = try parseSelectionSet(p, false);
    return Ast.Fragment.Definition{
        .name = name,
        .type_condition = type_cond,
        .directives = directives,
        .selection_set = selection_set,
        .span = p.endSpan(start),
    };
}

////    FragmentName: _Name_ but not `on`
fn parseFragmentName(
    p: *ParserImpl,
    /// How to treat `on` tokens
    /// - `true`: report a syntax error
    /// - `false`: panic
    comptime handle_kw_on: bool,
) ParserImpl.Error!Ast.Name {
    if (comptime handle_kw_on) {
        if (try p.eat(.kw_on)) |on| {
            @branchHint(.unlikely);
            p.report(diagnostics.fragmentNameCannotBeOn(on));
            return p.ast.name(on);
        }
    }
    p.assertNotWithoutAdvance(.kw_on);
    const name = p.ast.name(p.cur);
    try p.bump();
    return name;
}

/// `SelectionSet : { Selection+ }`
fn parseSelectionSet(
    p: *ParserImpl,
    /// Parse `SelectionSet?`, returning an empty set if not at `{`
    comptime opt: bool,
) ParserImpl.Error!Ast.Selection.Set {
    const start = p.startSpan();

    _ = if (comptime opt)
        try p.eat(.l_curly) orelse return .empty
    else
        try p.expect(.l_curly);

    // early check for `{}`
    if (try p.eat(.r_curly)) |_| {
        p.report(diagnostics.listCannotBeEmpty("Field Selections", p.endSpan(start)));
    }

    const selections = try parseSelectionList(p);
    _ = try p.expect(.r_curly);
    util.debugAssert(selections.len > 0);
    return Ast.Selection.Set{
        .selections = selections,
        .span = p.endSpan(start),
    };
}

const parseSelectionList = ParserImpl.parseListOf(Ast.Selection, parseSelection, &[_]Token.Kind{ .name, .spread });

fn parseSelection(p: *ParserImpl) !Ast.Selection {
    if (try p.eat(.spread)) |_| {
        // InlineFragment : `...` TypeCondition? Directives? SelectionSet
        // FragmentSpread : `...` FragmentName Directives?
        const start = p.startSpan();
        const tok = p.cur;
        return switch (tok.kind) {
            .l_curly => p.ast.selectionInlineFragmentSelectionOnly(try parseSelectionSet(p, false)),
            .kw_on => blk: {
                try p.assert(.kw_on);
                const type_condition: ?Ast.Type.Named = if (p.at(.name)) |_|
                    try types.parseNamedType(p)
                else missing: {
                    @branchHint(.unlikely);
                    // recover: `... on { ... }` is an inline fragment whose
                    // type condition never got written.
                    p.report(diagnostics.typeConditionIsMissingAType(tok));
                    break :missing null;
                };
                const directives = try expressions.parseDirectives(p);
                break :blk p.ast.selectionInlineFragment(
                    type_condition,
                    directives,
                    try parseSelectionSet(p, false),
                    p.endSpan(start),
                );
            },
            // InlineFragment with no type condition
            .at => blk: {
                const directives = try expressions.parseDirectives(p);
                const sel = try parseSelectionSet(p, false);
                break :blk p.ast.selectionInlineFragment(null, directives, sel, p.endSpan(start));
            },
            else => blk: {
                if (!tok.kind.isName()) return p.unexpectedToken();
                // FragmentSpread
                const name = try parseFragmentName(p, false);
                const directives = try expressions.parseDirectives(p);
                break :blk p.ast.selectionFragmentSpread(name, directives, p.endSpan(start));
            },
        };
    }
    return Ast.Selection{ .field = try parseField(p) };
}

/// `Field: Alias? Name Arguments? Directives? SelectionSet?
fn parseField(p: *ParserImpl) !Ast.Selection.Field {
    const start = p.startSpan();

    const name_or_alias = try p.parseName();
    const alias: ?Ast.Name, const name: Ast.Name = if (try p.eat(.colon)) |_|
        .{ name_or_alias, try p.parseName() }
    else
        .{ null, name_or_alias };

    const args = try expressions.parseArguments(p, true, false);
    const directives: []Ast.Directive = try expressions.parseDirectives(p);
    const selection_set = try parseSelectionSet(p, true);
    return Ast.Selection.Field{
        .alias = alias,
        .name = name,
        .arguments = args,
        .directives = directives,
        .selection_set = selection_set,
        .span = p.endSpan(start),
    };
}

/// Parses `VariablesDefinition?`
///     VariablesDefinition : `(` Variable.Definition+ `)`
fn parseVariablesDefinition(p: *ParserImpl) ![]Ast.Variable.Definition {
    const parseVarDefList = ParserImpl.parseListOf(Ast.Variable.Definition, parseVariableDefinition, &[_]Token.Kind{.dollar});
    _ = try p.eat(.l_paren) orelse return &[_]Ast.Variable.Definition{};
    const vars = try parseVarDefList(p);
    _ = try p.expect(.r_paren);
    return vars;
}

///    Variable.Definition :
///        Variable `:` Type DefaultValue? Directives[Const]?
fn parseVariableDefinition(p: *ParserImpl) !Ast.Variable.Definition {
    const start = p.startSpan();
    const variable = try values.parseVariable(p);
    _ = try p.expect(.colon); // TODO: attempt to recover

    const ty = try p.parseType();
    const default_value = if (try p.eat(.equal)) |_| try p.parseValue(true) else null;
    // TODO:  Directives

    return Ast.Variable.Definition{
        .variable = variable,
        .type = ty,
        .default_value = default_value,
        .directives = null, // TODO
        .span = p.endSpan(start),
    };
}

/// `TypeCondition : on NamedType`
fn parseTypeCondition(p: *ParserImpl) !Ast.Type.Named {
    _ = try p.expect(.kw_on);
    return types.parseNamedType(p);
}
