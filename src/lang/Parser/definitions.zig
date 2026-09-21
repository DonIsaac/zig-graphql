const std = @import("std");
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
    return switch (p.cur.kind) {
        .kw_query,
        .kw_mutation,
        .kw_subscription,
        .kw_fragment,
        .l_curly,
        => .{ .executable = try parseExecutableDefinition(p) },
        else => .{ .type_system = try parseTypeSystemDefinitionOrExtension(p) },
    };
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

///     TypeSystemDefinitionOrExtension:
///         TypeSystemDefinition
///         TypeSystemExtension
pub fn parseTypeSystemDefinitionOrExtension(p: *ParserImpl) ParserImpl.Error!Ast.TypeSystem.DefinitionOrExtension {
    return if (p.at(.kw_extend)) |_|
        .{ .extension = try parseTypeSystemExtension(p) }
    else
        .{ .definition = try parseTypeSystemDefinition(p) };
}

///    OperationDefinition :
///        OperationType Name? VariablesDefinition? Directives? SelectionSet
///        SelectionSet
fn parseOperationDefinition(p: *ParserImpl) !Ast.Operation.Definition {
    const start = p.startSpan();
    if (p.at(.l_curly)) |_| return p.ast.anonymousOperationDefinition(try parseSelectionSet(p, false));

    // TODO: maybe collapse with switch in `parseExecutableDefinition`. depends
    // on tradeoff: perf vs clarity-from-following-grammar-exactly
    const op = try parseOperationType(p);
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
                const directives = try parseDirectives(p);
                break :blk p.ast.selectionInlineFragment(
                    type_condition,
                    directives,
                    try parseSelectionSet(p, false),
                    p.endSpan(start),
                );
            },
            // InlineFragment with no type condition
            .at => blk: {
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

    const parseArgList = ParserImpl.parseListOf(Ast.Argument, Wrapper.parse, &[_]Token.Kind{.name});
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
const parseDirectives = DirectiveListParser(false);
/// `Directives[Const] : Directive[Const]+`
const parseConstDirectives = DirectiveListParser(true);

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

/// Spec spellings (`FIELD_DEFINITION`) of each `Location`, whose tags are the
/// same names in snake case.
const directive_locations: std.StaticStringMap(Ast.Directive.Definition.Location) = locations: {
    @setEvalBranchQuota(10_000);
    const fields = @typeInfo(Ast.Directive.Definition.Location).@"enum".fields;
    var kvs: [fields.len]struct { []const u8, Ast.Directive.Definition.Location } = undefined;
    for (&kvs, fields) |*kv, field| {
        var upper: [field.name.len]u8 = undefined;
        for (&upper, field.name) |*c, lower| c.* = std.ascii.toUpper(lower);
        const spelling = upper;
        kv.* = .{ &spelling, @enumFromInt(field.value) };
    }
    break :locations .initComptime(kvs);
};

///     DirectiveLocations :
///         `|`? DirectiveLocation
///         DirectiveLocations `|` DirectiveLocation
fn parseDirectiveLocations(p: *ParserImpl) ParserImpl.Error![]Ast.Directive.Definition.Location {
    var locations = try p.ast.list(Ast.Directive.Definition.Location, 1);
    _ = try p.eat(.pipe); // leading `|` is optional

    while (true) {
        try locations.append(p.allocator(), try parseDirectiveLocation(p));
        _ = try p.eat(.pipe) orelse break;
    }

    return p.ast.intoSlice(Ast.Directive.Definition.Location, &locations);
}

///     DirectiveLocation : ExecutableDirectiveLocation | TypeSystemDirectiveLocation
fn parseDirectiveLocation(p: *ParserImpl) ParserImpl.Error!Ast.Directive.Definition.Location {
    const tok = try p.expectWithoutAdvance(.name);
    const location = directive_locations.get(p.ast.slice(tok)) orelse
        return p.reportFatal(error.UnexpectedToken, diagnostics.unknownDirectiveLocation(tok));
    try p.bump();
    return location;
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

///     TypeSystemDefinition:
///         SchemaDefinition
///         TypeDefinition
///         DirectiveDefinition
fn parseTypeSystemDefinition(p: *ParserImpl) ParserImpl.Error!Ast.TypeSystem.Definition {
    const start = p.startSpan();
    const description = try parseDescription(p);
    switch (p.cur.kind) {
        .kw_schema => return .{ .schema = try parseSchemaDefinition(p, description, start) },
        .kw_type => {
            @panic("todo: TypeDefinition");
        },
        // DirectiveDefinition
        //   Description[opt] `directive` `@` Name ArgumentsDefinition[opt] Directives[Const][opt] `repeatable`[opt] `on` DirectiveLocations
        .kw_directive => {
            try p.assert(.kw_directive);
            _ = try p.expect(.at);
            const name = try p.parseName();
            const arguments = if (p.at(.l_paren)) |_| try parseArgumentsDefinition(p) else null;
            const directives = try parseConstDirectives(p);
            const repeatable = try p.eat(.kw_repeatable) != null;
            _ = try p.expect(.kw_on);
            const locations = try parseDirectiveLocations(p);

            return Ast.TypeSystem.Definition{ .directive = .{
                .description = description,
                .name = name,
                .arguments = arguments,
                .directives = directives,
                .repeatable = repeatable,
                .locations = locations,
                .span = p.endSpan(start),
            } };
        },
        else => return p.expectedToken("'schema', 'type', or 'directive'"),
    }
    @panic("todo");
}

///     SchemaDefinition :
///         Description? `schema` Directives[Const]? `{` RootOperationTypeDefinition+ `}`
///
/// `description` and `start` come from `parseTypeSystemDefinition`, which has
/// already consumed the description this definition's span starts at.
fn parseSchemaDefinition(
    p: *ParserImpl,
    description: ?Ast.Value.String,
    start: u32,
) ParserImpl.Error!Ast.Schema.Definition {
    try p.assert(.kw_schema);

    const directives = try parseConstDirectives(p);
    const operations_start = p.startSpan();
    _ = try p.expect(.l_curly);

    // a schema has at most one root operation type per operation type
    var operation_types = try p.ast.list(Ast.Schema.RootOperationTypeDefinition, @typeInfo(Ast.Operation.Type).@"enum".fields.len);
    while (try p.eat(.r_curly) == null) {
        const operation_type = try parseRootOperationTypeDefinition(p);
        try operation_types.append(p.allocator(), operation_type);
        _ = try p.eat(.comma);
    }

    if (operation_types.items.len == 0) {
        p.report(diagnostics.listCannotBeEmpty("Root operation types", p.endSpan(operations_start)));
    }

    return Ast.Schema.Definition{
        .description = description,
        .directives = directives,
        .operation_types = try p.ast.intoSlice(Ast.Schema.RootOperationTypeDefinition, &operation_types),
        .span = p.endSpan(start),
    };
}

fn parseTypeSystemExtension(p: *ParserImpl) ParserImpl.Error!Ast.TypeSystem.Extension {
    _ = p;
    @panic("todo: TypeSystemExtension");
}

///     ArgumentsDefinition
///         `(` InputValueDefinition[list] `)`
fn parseArgumentsDefinition(p: *ParserImpl) ParserImpl.Error![]Ast.InputValueDefinition {
    const start = p.startSpan();
    _ = try p.expect(.l_paren);

    var definitions = try p.ast.list(Ast.InputValueDefinition, 1);
    while (try p.eat(.r_paren) == null) {
        const def = try parseInputValueDefinition(p);
        try definitions.append(p.allocator(), def);
        _ = try p.eat(.comma);
    }

    if (definitions.items.len == 0) {
        p.report(diagnostics.listCannotBeEmpty("Argument definitions", p.endSpan(start)));
    }

    return p.ast.intoSlice(Ast.InputValueDefinition, &definitions);
}

///     InputValueDefinition
///         Description[opt] Name `:` Type DefaultValue[opt] Directives[Const][opt]
fn parseInputValueDefinition(p: *ParserImpl) ParserImpl.Error!Ast.InputValueDefinition {
    const start = p.startSpan();
    const description = try parseDescription(p);
    const name = try p.parseName();
    _ = try p.expect(.colon);
    const ty = try p.parseType();
    const default = if (try p.eat(.equal)) |_| try p.parseValue(true) else null;
    const directives = try parseConstDirectives(p);

    return Ast.InputValueDefinition{
        .description = description,
        .default_value = default,
        .name = name,
        .type = ty,
        .directives = directives,
        .span = p.endSpan(start),
    };
}

fn parseDescription(p: *ParserImpl) !?Ast.Value.String {
    return switch (p.cur.kind) {
        .string_value, .block_string_value => try p.parseStringValue(),
        else => null,
    };
}

///     RootOperationTypeDefinition:
///         OperationType `:` NamedType
fn parseRootOperationTypeDefinition(p: *ParserImpl) ParserImpl.Error!Ast.Schema.RootOperationTypeDefinition {
    const start = p.startSpan();
    const op_type = try parseOperationType(p);
    _ = try p.expect(.colon);
    const ty = try types.parseNamedType(p);

    return .{ .operation_type = op_type, .type = ty, .span = p.endSpan(start) };
}

///     OperationType: one of
///         `query` `mutation` `subscription`
fn parseOperationType(p: *ParserImpl) !Ast.Operation.Type {
    const ty: Ast.Operation.Type = switch (p.cur.kind) {
        .kw_query => .query,
        .kw_mutation => .mutation,
        .kw_subscription => .subscription,
        else => return p.expectedToken("an operation type"),
    };
    try p.bump();
    return ty;
}
