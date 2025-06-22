//! GraphQL AST data structure
const std = @import("std");
const Span = @import("Span.zig").Span;

const Ast = @This();

/// Represents a complete GraphQL document
pub const Document = struct {
    definitions: []Definition,
    loc: Span,
};

/// A definition in a GraphQL document
pub const Definition = union(enum) {
    executable: ExecutableDefinition,
    type_system: TypeSystemDefinitionOrExtension,
};

/// An executable definition (operation or fragment)
pub const ExecutableDefinition = union(enum) {
    operation: OperationDefinition,
    fragment: FragmentDefinition,
};

/// A GraphQL operation (query, mutation, or subscription)
pub const OperationDefinition = struct {
    operation_type: OperationType,
    name: ?Name,
    variable_definitions: ?[]VariableDefinition,
    directives: ?[]Directive,
    selection_set: SelectionSet,
    loc: Span,
};

/// The type of operation
pub const OperationType = enum {
    query,
    mutation,
    subscription,
};

/// A selection set containing fields, fragment spreads, and inline fragments
pub const SelectionSet = struct {
    selections: []Selection,
    loc: Span,
};

/// A selection in a selection set
pub const Selection = union(enum) {
    field: Field,
    fragment_spread: FragmentSpread,
    inline_fragment: InlineFragment,
};

/// A field selection
pub const Field = struct {
    alias: ?Name,
    name: Name,
    arguments: ?[]Argument,
    directives: ?[]Directive,
    selection_set: ?SelectionSet,
    loc: Span,
};

/// A fragment spread
pub const FragmentSpread = struct {
    name: Name,
    directives: ?[]Directive,
    loc: Span,
};

/// An inline fragment
pub const InlineFragment = struct {
    type_condition: ?NamedType,
    directives: ?[]Directive,
    selection_set: SelectionSet,
    loc: Span,
};

/// A fragment definition
pub const FragmentDefinition = struct {
    name: Name,
    type_condition: NamedType,
    directives: ?[]Directive,
    selection_set: SelectionSet,
    loc: Span,
};

/// A variable definition
pub const VariableDefinition = struct {
    variable: Variable,
    type: Type,
    default_value: ?Value,
    directives: ?[]Directive,
    loc: Span,
};

/// A variable reference
pub const Variable = struct {
    name: Name,
    loc: Span,
};

/// A field argument
pub const Argument = struct {
    name: Name,
    value: Value,
    loc: Span,
};

/// A directive
pub const Directive = struct {
    name: Name,
    arguments: ?[]Argument,
    loc: Span,
};

/// A GraphQL value
pub const Value = union(enum) {
    variable: Variable,
    int_value: IntValue,
    float_value: FloatValue,
    string_value: StringValue,
    boolean_value: BooleanValue,
    null_value: NullValue,
    enum_value: EnumValue,
    list_value: ListValue,
    object_value: ObjectValue,
};

/// An integer value
pub const IntValue = struct {
    value: []const u8,
    loc: Span,
};

/// A float value
pub const FloatValue = struct {
    value: []const u8,
    loc: Span,
};

/// A string value
pub const StringValue = struct {
    value: []const u8,
    block: bool, // true for block strings ("""), false for regular strings
    loc: Span,
};

/// A boolean value
pub const BooleanValue = struct {
    value: bool,
    loc: Span,
};

/// A null value
pub const NullValue = struct {
    loc: Span,
};

/// An enum value
pub const EnumValue = struct {
    value: Name,
    loc: Span,
};

/// A list value
pub const ListValue = struct {
    values: []Value,
    loc: Span,
};

/// An object value
pub const ObjectValue = struct {
    fields: []ObjectField,
    loc: Span,
};

/// A field in an object value
pub const ObjectField = struct {
    name: Name,
    value: Value,
    loc: Span,
};

/// A GraphQL type
pub const Type = union(enum) {
    named: Type.Named,
    list: Type.List,
    non_null: Type.NonNull,

    /// A list type
    pub const List = struct {
        type: Type,
        span: Span,
    };

    /// A non-null type
    pub const NonNull = struct {
        type: Type,
        span: Span,
    };

    /// A named type
    pub const Named = struct {
        name: Name,
        span: Span,
    };
};

/// A name token
pub const Name = struct {
    value: []const u8,
    loc: Span,
};

/// Type system definitions and extensions
pub const TypeSystemDefinitionOrExtension = union(enum) {
    definition: TypeSystemDefinition,
    extension: TypeSystemExtension,
};

/// Type system definitions
pub const TypeSystemDefinition = union(enum) {
    schema: SchemaDefinition,
    scalar: ScalarTypeDefinition,
    object: ObjectTypeDefinition,
    interface: InterfaceTypeDefinition,
    @"union": UnionTypeDefinition,
    @"enum": EnumTypeDefinition,
    input_object: InputObjectTypeDefinition,
    directive: DirectiveDefinition,
};

/// Type system extensions
pub const TypeSystemExtension = union(enum) {
    schema: SchemaExtension,
    scalar: ScalarTypeExtension,
    object: ObjectTypeExtension,
    interface: InterfaceTypeExtension,
    @"union": UnionTypeExtension,
    @"enum": EnumTypeExtension,
    input_object: InputObjectTypeExtension,
};

/// Schema definition
pub const SchemaDefinition = struct {
    description: ?StringValue,
    directives: ?[]Directive,
    operation_types: []RootOperationTypeDefinition,
    loc: Span,
};

/// Schema extension
pub const SchemaExtension = struct {
    directives: ?[]Directive,
    operation_types: ?[]RootOperationTypeDefinition,
    loc: Span,
};

/// Root operation type definition
pub const RootOperationTypeDefinition = struct {
    operation_type: OperationType,
    type: NamedType,
    loc: Span,
};

/// Scalar type definition
pub const ScalarTypeDefinition = struct {
    description: ?StringValue,
    name: Name,
    directives: ?[]Directive,
    loc: Span,
};

/// Scalar type extension
pub const ScalarTypeExtension = struct {
    name: Name,
    directives: ?[]Directive,
    loc: Span,
};

/// Object type definition
pub const ObjectTypeDefinition = struct {
    description: ?StringValue,
    name: Name,
    interfaces: ?[]NamedType,
    directives: ?[]Directive,
    fields: ?[]FieldDefinition,
    loc: Span,
};

/// Object type extension
pub const ObjectTypeExtension = struct {
    name: Name,
    interfaces: ?[]NamedType,
    directives: ?[]Directive,
    fields: ?[]FieldDefinition,
    loc: Span,
};

/// Interface type definition
pub const InterfaceTypeDefinition = struct {
    description: ?StringValue,
    name: Name,
    interfaces: ?[]NamedType,
    directives: ?[]Directive,
    fields: ?[]FieldDefinition,
    loc: Span,
};

/// Interface type extension
pub const InterfaceTypeExtension = struct {
    name: Name,
    interfaces: ?[]NamedType,
    directives: ?[]Directive,
    fields: ?[]FieldDefinition,
    loc: Span,
};

/// Union type definition
pub const UnionTypeDefinition = struct {
    description: ?StringValue,
    name: Name,
    directives: ?[]Directive,
    types: ?[]NamedType,
    loc: Span,
};

/// Union type extension
pub const UnionTypeExtension = struct {
    name: Name,
    directives: ?[]Directive,
    types: ?[]NamedType,
    loc: Span,
};

/// Enum type definition
pub const EnumTypeDefinition = struct {
    description: ?StringValue,
    name: Name,
    directives: ?[]Directive,
    values: ?[]EnumValueDefinition,
    loc: Span,
};

/// Enum type extension
pub const EnumTypeExtension = struct {
    name: Name,
    directives: ?[]Directive,
    values: ?[]EnumValueDefinition,
    loc: Span,
};

/// Input object type definition
pub const InputObjectTypeDefinition = struct {
    description: ?StringValue,
    name: Name,
    directives: ?[]Directive,
    fields: ?[]InputValueDefinition,
    loc: Span,
};

/// Input object type extension
pub const InputObjectTypeExtension = struct {
    name: Name,
    directives: ?[]Directive,
    fields: ?[]InputValueDefinition,
    loc: Span,
};

/// Directive definition
pub const DirectiveDefinition = struct {
    description: ?StringValue,
    name: Name,
    arguments: ?[]InputValueDefinition,
    repeatable: bool,
    locations: []DirectiveLocation,
    loc: Span,
};

/// Field definition
pub const FieldDefinition = struct {
    description: ?StringValue,
    name: Name,
    arguments: ?[]InputValueDefinition,
    type: Type,
    directives: ?[]Directive,
    loc: Span,
};

/// Input value definition
pub const InputValueDefinition = struct {
    description: ?StringValue,
    name: Name,
    type: Type,
    default_value: ?Value,
    directives: ?[]Directive,
    loc: Span,
};

/// Enum value definition
pub const EnumValueDefinition = struct {
    description: ?StringValue,
    value: EnumValue,
    directives: ?[]Directive,
    loc: Span,
};

/// Directive location
pub const DirectiveLocation = enum {
    // Executable directive locations
    query,
    mutation,
    subscription,
    field,
    fragment_definition,
    fragment_spread,
    inline_fragment,
    variable_definition,

    // Type system directive locations
    schema,
    scalar,
    object,
    field_definition,
    argument_definition,
    interface,
    @"union",
    @"enum",
    enum_value,
    input_object,
    input_field_definition,
};
