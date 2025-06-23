const ParserImpl = @import("ParserImpl.zig");
const Ast = @import("../Ast.zig");
const Token = @import("../Lexer.zig").Token;

const values = @import("values.zig");
const types = @import("types.zig");
const diagnostics = @import("diagnostics.zig");

pub fn parseDefinition(p: *ParserImpl) !Ast.Definition {
    // TODO: type system definition
    return .{ .executable = try parseExecutableDefinition(p) };
}
pub fn parseExecutableDefinition(
    p: *ParserImpl,
) !Ast.ExecutableDefinition {
    // return switch (p.cur.kind) {
    //     .kw_query, .kw_mutation, .kw_subscription => .{ .operation = try parseOperationDefinition(p) },
    //     .kw_fragment => .{ .fragment = try parseFragmentDefinition(p) },
    //     else => p.unexpectedToken(),
    // };
    return if (p.at(.kw_fragment)) |_|
        .{ .fragment = try parseFragmentDefinition(p) }
    else
        .{ .operation = try parseOperationDefinition(p) };
}

///    OperationDefinition :
///        OperationType Name? VariablesDefinition? Directives? SelectionSet
///        SelectionSet
fn parseOperationDefinition(p: *ParserImpl) !Ast.OperationDefinition {
    const start = p.startSpan();
    if (p.at(.l_bracket)) |_| return p.ast.anonymousOperationDefinition(try parseSelectionSet(p, false));

    // TODO: maybe collapse with switch in `parseExecutableDefinition`. depends
    // on tradeoff: perf vs clarity-from-following-grammar-exactly
    const op: Ast.OperationType = switch (p.cur.kind) {
        .kw_query => .query,
        .kw_mutation => .mutation,
        .kw_subscription => .subscription,
        .l_bracket => unreachable,
        else => return p.unexpectedToken(),
    };
    try p.bump();
    const name: ?Ast.Name = if (p.at(.name)) |_| try p.parseName() else null;
    const vars: []Ast.VariableDefinition = try parseVariablesDefinition(p);
    const directives: []Ast.Directive = try parseDirectives(p);
    const selection_set: Ast.Selection.Set = if (p.at(.l_curly)) |_| try parseSelectionSet(p, false) else .empty;

    return Ast.OperationDefinition{
        .operation_type = op,
        .name = name,
        .variable_definitions = vars,
        .directives = directives,
        .selection_set = selection_set,
        .span = p.endSpan(start),
    };
}

///    fragment FragmentName TypeCondition Directives? SelectionSet
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
        break :on p.ast.name(p.endSpan(start));
    } else try parseFragmentName(p, true);

    const type_cond = try parseTypeCondition(p);
    const directives: []Ast.Directive = try parseDirectives(p);
    const selection_set = try parseSelectionSet(p, false);
    return Ast.FragmentDefinition{
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
) !Ast.Name {
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

fn parseSelectionSet(p: *ParserImpl, comptime opt: bool) ParserImpl.Error!Ast.Selection.Set {
    const start = p.startSpan();

    if (comptime opt) {
        _ = try p.eat(.l_curly) orelse return .empty;
    } else {
        try p.expect(.l_curly);
    }

    const selections = try parseSelectionList(p);
    try p.expect(.r_curly);
    return Ast.Selection.Set{
        .selections = selections,
        .span = p.endSpan(start),
    };
}

const parseSelectionList = ParserImpl.parseListOf(Ast.Selection, parseSelection, &[_]Token.Kind{ .name, .spread });
fn parseSelection(p: *ParserImpl) !Ast.Selection {
    if (try p.eat(.spread)) |_| {
        if (p.at(.kw_on)) |_| {
            // InlineFragment : `...` TypeCondition? Directives? SelectionSet
            @panic("todo: inline fragment");
        } else {
            // FragmentSpread : `...` FragmentName Directives?
            @panic("todo: fragment spread");
        }
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
        const is_const = @"const";
        pub fn parse(p_: *ParserImpl) !Ast.Argument {
            return parseArgument(p_, is_const);
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
///     VariablesDefinition : `(` VariableDefinition+ `)`
fn parseVariablesDefinition(p: *ParserImpl) ![]Ast.VariableDefinition {
    const parseVarDefList = ParserImpl.parseListOf(Ast.VariableDefinition, parseVariableDefinition, &[_]Token.Kind{.dollar});
    _ = try p.eat(.l_paren) orelse return &[_]Ast.VariableDefinition{};
    const vars = try parseVarDefList(p);
    try p.expect(.r_paren);
    return vars;
}

///    VariableDefinition :
///        Variable `:` Type DefaultValue? Directives[Const]?
fn parseVariableDefinition(p: *ParserImpl) !Ast.VariableDefinition {
    const start = p.startSpan();
    const variable = try values.parseVariable(p);
    try p.expect(.colon); // TODO: attempt to recover

    const ty = try p.parseType();
    const default_value = if (try p.eat(.equal)) |_| try p.parseValue(true) else null;
    // TODO:  Directives

    return Ast.VariableDefinition{
        .variable = variable,
        .type = ty,
        .default_value = default_value,
        .directives = null, // TODO
        .span = p.endSpan(start),
    };
}

// todo: Ast.TypeCondition
fn parseTypeCondition(p: *ParserImpl) !Ast.Type.Named {
    return types.parseNamedType(p);
}
