const util = @import("../../util.zig");
const ParserImpl = @import("ParserImpl.zig");
const Ast = @import("../Ast.zig");
const Token = @import("../Lexer.zig").Token;

const values = @import("values.zig");
const types = @import("types.zig");
const diagnostics = @import("diagnostics.zig");

/// ## [2.2 Document - Definition](https://spec.graphql.org/draft/#sec-Document)
///
///     Definition:
///         ExecutableDefinition
///         TypeSystemDefinitionOrExtensions
pub fn parseDefinition(p: *ParserImpl) !Ast.Document.Definition {
    // TODO: type system definition
    return .{ .executable = try parseExecutableDefinition(p) };
}

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
    if (p.at(.l_bracket)) |_| return p.ast.anonymousOperationDefinition(try parseSelectionSet(p, false));

    // TODO: maybe collapse with switch in `parseExecutableDefinition`. depends
    // on tradeoff: perf vs clarity-from-following-grammar-exactly
    const op: Ast.Operation.Type = switch (p.cur.kind) {
        .kw_query => .query,
        .kw_mutation => .mutation,
        .kw_subscription => .subscription,
        .l_bracket => unreachable,
        else => return p.unexpectedToken(),
    };
    try p.bump();
    const name: ?Ast.Name = if (p.at(.name)) |_| try p.parseName() else null;
    const vars: []Ast.Variable.Definition = try parseVariablesDefinition(p);
    const directives: []Ast.Directive = try parseDirectives(p);
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
    const directives: []Ast.Directive = try parseDirectives(p);
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

    if (comptime opt) {
        _ = try p.eat(.l_curly) orelse return .empty;
    } else {
        try p.expect(.l_curly);
    }

    // early check for `{}`
    if (try p.eat(.r_curly)) |_| {
        @branchHint(.cold);
        p.report(diagnostics.listCannotBeEmpty("Field Selections", p.endSpan(start)));
    }

    const selections = try parseSelectionList(p);
    try p.expect(.r_curly);
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
                const directives = try parseDirectives(p);
                break :blk if (p.at(.l_curly)) |_|
                    // this is a selection set where type is 'on'
                    // at least I think we treat `on` as a type condition?
                    // break :blk Ast.Selection{ .inline_fragment = p.ast.inlineFragmentSelectionOnly(try parseSelectionSet(p, false)) };
                    p.ast.selectionInlineFragment(p.ast.namedType(tok), directives, try parseSelectionSet(p, false), p.endSpan(start))
                else
                    p.ast.selectionFragmentSpread(p.ast.name(tok), directives, p.endSpan(start));
            },
            // InlineFragment with no type condition
            .at => blk: {
                try p.assert(.at);
                const directives = try parseDirectives(p);
                const sel = try parseSelectionSet(p, false);
                break :blk p.ast.selectionInlineFragment(null, directives, sel, p.endSpan(start));
            },
            else => blk: {
                if (!tok.kind.isName()) return p.unexpectedToken();
                // FragmentSpread
                const name = try parseFragmentName(p, false);
                const directives = try parseDirectives(p);
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

    const args = try parseArguments(p, true, false);
    const directives: []Ast.Directive = try parseDirectives(p);
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

/// `Arguments[Const] : `(` Argument[?Const]+ `)`
pub fn parseArguments(p: *ParserImpl, comptime opt: bool, comptime @"const": bool) !Ast.Argument.List {
    const start = p.startSpan();

    if (comptime opt) {
        _ = try p.eat(.l_paren) orelse return Ast.Argument.List.empty;
    } else {
        try p.expect(.l_paren);
    }

    const args = try parseArgumentList(p, @"const");
    try p.expect(.r_paren);

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
    try p.expect(.colon);
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

    const parseArgList = ParserImpl.parseListOf(Ast.Argument, Wrapper.parse, &[_]Token.Kind{.name});
    return parseArgList(p);
}

/// `Directives[Const] : Directive[?Const]+`
const parseDirectives = ParserImpl.parseListOf(Ast.Directive, parseDirective, &[_]Token.Kind{.at});
/// `Directive[Const] : @ Name Arguments[?Const]?`
fn parseDirective(p: *ParserImpl) !Ast.Directive {
    _ = &p;
    @panic("todo");
}

/// Parses `VariablesDefinition?`
///     VariablesDefinition : `(` Variable.Definition+ `)`
fn parseVariablesDefinition(p: *ParserImpl) ![]Ast.Variable.Definition {
    const parseVarDefList = ParserImpl.parseListOf(Ast.Variable.Definition, parseVariableDefinition, &[_]Token.Kind{.dollar});
    _ = try p.eat(.l_paren) orelse return &[_]Ast.Variable.Definition{};
    const vars = try parseVarDefList(p);
    try p.expect(.r_paren);
    return vars;
}

///    Variable.Definition :
///        Variable `:` Type DefaultValue? Directives[Const]?
fn parseVariableDefinition(p: *ParserImpl) !Ast.Variable.Definition {
    const start = p.startSpan();
    const variable = try values.parseVariable(p);
    try p.expect(.colon); // TODO: attempt to recover

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

/// `TypeCondition : NamedType`
fn parseTypeCondition(p: *ParserImpl) !Ast.Type.Named {
    return types.parseNamedType(p);
}
