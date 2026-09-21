const std = @import("std");
const ParserImpl = @import("ParserImpl.zig");
const Ast = @import("../Ast.zig");
const Token = @import("../Lexer.zig").Token;

const expressions = @import("expressions.zig");
const types = @import("types.zig");
const diagnostics = @import("diagnostics.zig");

/// Directives are `[Const]` everywhere in the type system.
const parseDirectives = expressions.parseConstDirectives;

///     TypeSystemDefinitionOrExtension:
///         TypeSystemDefinition
///         TypeSystemExtension
pub fn parseTypeSystemDefinitionOrExtension(p: *ParserImpl) ParserImpl.Error!Ast.TypeSystem.DefinitionOrExtension {
    return if (p.at(.kw_extend)) |_|
        .{ .extension = try parseTypeSystemExtension(p) }
    else
        .{ .definition = try parseTypeSystemDefinition(p) };
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
        .kw_scalar,
        .kw_type,
        .kw_interface,
        .kw_union,
        .kw_enum,
        .kw_input,
        => return parseTypeDefinition(p, description, start),
        // DirectiveDefinition
        //   Description[opt] `directive` `@` Name ArgumentsDefinition[opt] Directives[Const][opt] `repeatable`[opt] `on` DirectiveLocations
        .kw_directive => {
            try p.assert(.kw_directive);
            _ = try p.expect(.at);
            const name = try p.parseName();
            const arguments = if (p.at(.l_paren)) |_| try parseArgumentsDefinition(p) else null;
            const directives = try parseDirectives(p);
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
        else => return p.expectedToken("a schema, type, or directive definition"),
    }
    @panic("todo");
}

fn parseTypeSystemExtension(p: *ParserImpl) ParserImpl.Error!Ast.TypeSystem.Extension {
    _ = p;
    @panic("todo: TypeSystemExtension");
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

    const directives = try parseDirectives(p);
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

///     RootOperationTypeDefinition:
///         OperationType `:` NamedType
fn parseRootOperationTypeDefinition(p: *ParserImpl) ParserImpl.Error!Ast.Schema.RootOperationTypeDefinition {
    const start = p.startSpan();
    const op_type = try expressions.parseOperationType(p);
    _ = try p.expect(.colon);
    const ty = try types.parseNamedType(p);

    return .{ .operation_type = op_type, .type = ty, .span = p.endSpan(start) };
}

///     TypeDefinition :
///         ScalarTypeDefinition
///         ObjectTypeDefinition
///         InterfaceTypeDefinition
///         UnionTypeDefinition
///         EnumTypeDefinition
///         InputObjectTypeDefinition
///
/// `description` and `start` come from `parseTypeSystemDefinition`, which has
/// already consumed the description this definition's span starts at.
fn parseTypeDefinition(
    p: *ParserImpl,
    description: ?Ast.Value.String,
    start: u32,
) ParserImpl.Error!Ast.TypeSystem.Definition {
    return switch (p.cur.kind) {
        .kw_scalar => .{ .scalar = try parseScalarTypeDefinition(p, description, start) },
        .kw_type => .{ .object = try parseObjectTypeDefinition(p, description, start) },
        .kw_interface => .{ .interface = try parseInterfaceTypeDefinition(p, description, start) },
        .kw_union => .{ .@"union" = try parseUnionTypeDefinition(p, description, start) },
        .kw_enum => .{ .@"enum" = try parseEnumTypeDefinition(p, description, start) },
        .kw_input => .{ .input_object = try parseInputObjectTypeDefinition(p, description, start) },
        else => p.expectedToken("a type definition"),
    };
}

///     ScalarTypeDefinition : Description? `scalar` Name Directives[Const]?
fn parseScalarTypeDefinition(
    p: *ParserImpl,
    description: ?Ast.Value.String,
    start: u32,
) ParserImpl.Error!Ast.ScalarType.Definition {
    try p.assert(.kw_scalar);

    const name = try p.parseName();
    const directives = try parseDirectives(p);

    return Ast.ScalarType.Definition{
        .description = description,
        .name = name,
        .directives = directives,
        .span = p.endSpan(start),
    };
}

///     ObjectTypeDefinition :
///         Description? `type` Name ImplementsInterfaces? Directives[Const]? FieldsDefinition?
fn parseObjectTypeDefinition(
    p: *ParserImpl,
    description: ?Ast.Value.String,
    start: u32,
) ParserImpl.Error!Ast.ObjectType.Definition {
    try p.assert(.kw_type);

    const name = try p.parseName();
    const interfaces = try parseImplementsInterfaces(p);
    const directives = try parseDirectives(p);
    const fields = if (p.at(.l_curly)) |_| try parseFieldsDefinition(p) else null;

    return Ast.ObjectType.Definition{
        .description = description,
        .name = name,
        .interfaces = interfaces,
        .directives = directives,
        .fields = fields,
        .span = p.endSpan(start),
    };
}

///     InterfaceTypeDefinition :
///         Description? `interface` Name ImplementsInterfaces? Directives[Const]? FieldsDefinition?
fn parseInterfaceTypeDefinition(
    p: *ParserImpl,
    description: ?Ast.Value.String,
    start: u32,
) ParserImpl.Error!Ast.InterfaceType.Definition {
    try p.assert(.kw_interface);

    const name = try p.parseName();
    const interfaces = try parseImplementsInterfaces(p);
    const directives = try parseDirectives(p);
    const fields = if (p.at(.l_curly)) |_| try parseFieldsDefinition(p) else null;

    return Ast.InterfaceType.Definition{
        .description = description,
        .name = name,
        .interfaces = interfaces,
        .directives = directives,
        .fields = fields,
        .span = p.endSpan(start),
    };
}

///     UnionTypeDefinition :
///         Description? `union` Name Directives[Const]? UnionMemberTypes?
fn parseUnionTypeDefinition(
    p: *ParserImpl,
    description: ?Ast.Value.String,
    start: u32,
) ParserImpl.Error!Ast.UnionType.Definition {
    try p.assert(.kw_union);

    const name = try p.parseName();
    const directives = try parseDirectives(p);
    const member_types = try parseUnionMemberTypes(p);

    return Ast.UnionType.Definition{
        .description = description,
        .name = name,
        .directives = directives,
        .types = member_types,
        .span = p.endSpan(start),
    };
}

///     EnumTypeDefinition :
///         Description? `enum` Name Directives[Const]? EnumValuesDefinition?
fn parseEnumTypeDefinition(
    p: *ParserImpl,
    description: ?Ast.Value.String,
    start: u32,
) ParserImpl.Error!Ast.EnumType.Definition {
    try p.assert(.kw_enum);

    const name = try p.parseName();
    const directives = try parseDirectives(p);
    const enum_values = if (p.at(.l_curly)) |_| try parseEnumValuesDefinition(p) else null;

    return Ast.EnumType.Definition{
        .description = description,
        .name = name,
        .directives = directives,
        .values = enum_values,
        .span = p.endSpan(start),
    };
}

///     InputObjectTypeDefinition :
///         Description? `input` Name Directives[Const]? InputFieldsDefinition?
fn parseInputObjectTypeDefinition(
    p: *ParserImpl,
    description: ?Ast.Value.String,
    start: u32,
) ParserImpl.Error!Ast.InputObjectType.Definition {
    try p.assert(.kw_input);

    const name = try p.parseName();
    const directives = try parseDirectives(p);
    const fields = if (p.at(.l_curly)) |_| try parseInputFieldsDefinition(p) else null;

    return Ast.InputObjectType.Definition{
        .description = description,
        .name = name,
        .directives = directives,
        .fields = fields,
        .span = p.endSpan(start),
    };
}

///     ImplementsInterfaces :
///         `implements` `&`? NamedType
///         ImplementsInterfaces `&` NamedType
fn parseImplementsInterfaces(p: *ParserImpl) ParserImpl.Error!?[]Ast.Type.Named {
    _ = try p.eat(.kw_implements) orelse return null;
    return try parseNamedTypeList(p, .amp);
}

///     UnionMemberTypes :
///         `=` `|`? NamedType
///         UnionMemberTypes `|` NamedType
fn parseUnionMemberTypes(p: *ParserImpl) ParserImpl.Error!?[]Ast.Type.Named {
    _ = try p.eat(.equal) orelse return null;
    return try parseNamedTypeList(p, .pipe);
}

/// A `separator`-delimited list of named types. A leading separator is allowed.
fn parseNamedTypeList(p: *ParserImpl, comptime separator: Token.Kind) ParserImpl.Error![]Ast.Type.Named {
    var named_types = try p.ast.list(Ast.Type.Named, 1);
    _ = try p.eat(separator);

    while (true) {
        try named_types.append(p.allocator(), try types.parseNamedType(p));
        _ = try p.eat(separator) orelse break;
    }

    return p.ast.intoSlice(Ast.Type.Named, &named_types);
}

/// Parses `{` Node+ `}`, the shape shared by `FieldsDefinition`,
/// `EnumValuesDefinition`, and `InputFieldsDefinition`.
fn BracedListParser(
    comptime Node: type,
    comptime parseNode: ParserImpl.Fn(Node),
    /// what the list holds, for the "must have at least one item" diagnostic
    comptime name_plural: []const u8,
) ParserImpl.Fn([]Node) {
    return struct {
        pub fn parseBracedList(p: *ParserImpl) ParserImpl.Error![]Node {
            const start = p.startSpan();
            _ = try p.expect(.l_curly);

            var nodes = try p.ast.list(Node, 4);
            while (try p.eat(.r_curly) == null) {
                const node = try parseNode(p);
                try nodes.append(p.allocator(), node);
                _ = try p.eat(.comma);
            }

            if (nodes.items.len == 0) {
                p.report(diagnostics.listCannotBeEmpty(name_plural, p.endSpan(start)));
            }

            return p.ast.intoSlice(Node, &nodes);
        }
    }.parseBracedList;
}

///     FieldsDefinition : `{` FieldDefinition+ `}`
const parseFieldsDefinition = BracedListParser(Ast.FieldDefinition, parseFieldDefinition, "Field definitions");

///     FieldDefinition :
///         Description? Name ArgumentsDefinition? `:` Type Directives[Const]?
fn parseFieldDefinition(p: *ParserImpl) ParserImpl.Error!Ast.FieldDefinition {
    const start = p.startSpan();

    const description = try parseDescription(p);
    const name = try p.parseName();
    const arguments = if (p.at(.l_paren)) |_| try parseArgumentsDefinition(p) else null;
    _ = try p.expect(.colon);
    const ty = try p.parseType();
    const directives = try parseDirectives(p);

    return Ast.FieldDefinition{
        .description = description,
        .name = name,
        .arguments = arguments,
        .type = ty,
        .directives = directives,
        .span = p.endSpan(start),
    };
}

///     EnumValuesDefinition : `{` EnumValueDefinition+ `}`
const parseEnumValuesDefinition = BracedListParser(Ast.EnumValueDefinition, parseEnumValueDefinition, "Enum values");

///     EnumValueDefinition : Description? EnumValue Directives[Const]?
fn parseEnumValueDefinition(p: *ParserImpl) ParserImpl.Error!Ast.EnumValueDefinition {
    const start = p.startSpan();

    const description = try parseDescription(p);
    const value = try parseEnumValue(p);
    const directives = try parseDirectives(p);

    return Ast.EnumValueDefinition{
        .description = description,
        .value = value,
        .directives = directives,
        .span = p.endSpan(start),
    };
}

///     EnumValue : Name but not `true`, `false` or `null`
fn parseEnumValue(p: *ParserImpl) ParserImpl.Error!Ast.Value.Enum {
    switch (p.cur.kind) {
        .kw_true, .kw_false, .kw_null => {
            // recover: take the reserved word as the value's name
            const tok = p.cur;
            p.report(diagnostics.enumValueCannotBeReserved(tok));
            try p.bump();
            return Ast.Value.Enum{ .value = p.ast.name(tok) };
        },
        else => return Ast.Value.Enum{ .value = try p.parseName() },
    }
}

///     InputFieldsDefinition : `{` InputValueDefinition+ `}`
const parseInputFieldsDefinition = BracedListParser(Ast.InputValueDefinition, parseInputValueDefinition, "Input field definitions");

///     ArgumentsDefinition
///         `(` InputValueDefinition[list] `)`
fn parseArgumentsDefinition(p: *ParserImpl) ParserImpl.Error![]Ast.InputValueDefinition {
    const start = p.startSpan();
    _ = try p.expect(.l_paren);

    var arguments = try p.ast.list(Ast.InputValueDefinition, 1);
    while (try p.eat(.r_paren) == null) {
        const argument = try parseInputValueDefinition(p);
        try arguments.append(p.allocator(), argument);
        _ = try p.eat(.comma);
    }

    if (arguments.items.len == 0) {
        p.report(diagnostics.listCannotBeEmpty("Argument definitions", p.endSpan(start)));
    }

    return p.ast.intoSlice(Ast.InputValueDefinition, &arguments);
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
    const directives = try parseDirectives(p);

    return Ast.InputValueDefinition{
        .description = description,
        .default_value = default,
        .name = name,
        .type = ty,
        .directives = directives,
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

fn parseDescription(p: *ParserImpl) !?Ast.Value.String {
    return switch (p.cur.kind) {
        .string_value, .block_string_value => try p.parseStringValue(),
        else => null,
    };
}
