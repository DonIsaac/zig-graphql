//! GraphQL AST data structure
const std = @import("std");

const Ast = @This();

/// Represents a complete GraphQL document
pub const Document = struct {
    definitions: []Definition,
    loc: ?Location = null,
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
    loc: ?Location = null,
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
    loc: ?Location = null,
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
    loc: ?Location = null,
};

/// A fragment spread
pub const FragmentSpread = struct {
    name: Name,
    directives: ?[]Directive,
    loc: ?Location = null,
};

/// An inline fragment
pub const InlineFragment = struct {
    type_condition: ?NamedType,
    directives: ?[]Directive,
    selection_set: SelectionSet,
    loc: ?Location = null,
};

/// A fragment definition
pub const FragmentDefinition = struct {
    name: Name,
    type_condition: NamedType,
    directives: ?[]Directive,
    selection_set: SelectionSet,
    loc: ?Location = null,
};

/// A variable definition
pub const VariableDefinition = struct {
    variable: Variable,
    type: Type,
    default_value: ?Value,
    directives: ?[]Directive,
    loc: ?Location = null,
};

/// A variable reference
pub const Variable = struct {
    name: Name,
    loc: ?Location = null,
};

/// A field argument
pub const Argument = struct {
    name: Name,
    value: Value,
    loc: ?Location = null,
};

/// A directive
pub const Directive = struct {
    name: Name,
    arguments: ?[]Argument,
    loc: ?Location = null,
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
    loc: ?Location = null,
};

/// A float value
pub const FloatValue = struct {
    value: []const u8,
    loc: ?Location = null,
};

/// A string value
pub const StringValue = struct {
    value: []const u8,
    block: bool, // true for block strings ("""), false for regular strings
    loc: ?Location = null,
};

/// A boolean value
pub const BooleanValue = struct {
    value: bool,
    loc: ?Location = null,
};

/// A null value
pub const NullValue = struct {
    loc: ?Location = null,
};

/// An enum value
pub const EnumValue = struct {
    value: Name,
    loc: ?Location = null,
};

/// A list value
pub const ListValue = struct {
    values: []Value,
    loc: ?Location = null,
};

/// An object value
pub const ObjectValue = struct {
    fields: []ObjectField,
    loc: ?Location = null,
};

/// A field in an object value
pub const ObjectField = struct {
    name: Name,
    value: Value,
    loc: ?Location = null,
};

/// A GraphQL type
pub const Type = union(enum) {
    named: NamedType,
    list: *Type,
    non_null: *Type,
};

/// A named type
pub const NamedType = struct {
    name: Name,
    loc: ?Location = null,
};

/// A name token
pub const Name = struct {
    value: []const u8,
    loc: ?Location = null,
};

/// Source location information
pub const Location = struct {
    start: usize,
    end: usize,
    start_line: usize,
    start_column: usize,
    end_line: usize,
    end_column: usize,
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
    union: UnionTypeDefinition,
    enum: EnumTypeDefinition,
    input_object: InputObjectTypeDefinition,
    directive: DirectiveDefinition,
};

/// Type system extensions
pub const TypeSystemExtension = union(enum) {
    schema: SchemaExtension,
    scalar: ScalarTypeExtension,
    object: ObjectTypeExtension,
    interface: InterfaceTypeExtension,
    union: UnionTypeExtension,
    enum: EnumTypeExtension,
    input_object: InputObjectTypeExtension,
};

/// Schema definition
pub const SchemaDefinition = struct {
    description: ?StringValue,
    directives: ?[]Directive,
    operation_types: []RootOperationTypeDefinition,
    loc: ?Location = null,
};

/// Schema extension
pub const SchemaExtension = struct {
    directives: ?[]Directive,
    operation_types: ?[]RootOperationTypeDefinition,
    loc: ?Location = null,
};

/// Root operation type definition
pub const RootOperationTypeDefinition = struct {
    operation_type: OperationType,
    type: NamedType,
    loc: ?Location = null,
};

/// Scalar type definition
pub const ScalarTypeDefinition = struct {
    description: ?StringValue,
    name: Name,
    directives: ?[]Directive,
    loc: ?Location = null,
};

/// Scalar type extension
pub const ScalarTypeExtension = struct {
    name: Name,
    directives: ?[]Directive,
    loc: ?Location = null,
};

/// Object type definition
pub const ObjectTypeDefinition = struct {
    description: ?StringValue,
    name: Name,
    interfaces: ?[]NamedType,
    directives: ?[]Directive,
    fields: ?[]FieldDefinition,
    loc: ?Location = null,
};

/// Object type extension
pub const ObjectTypeExtension = struct {
    name: Name,
    interfaces: ?[]NamedType,
    directives: ?[]Directive,
    fields: ?[]FieldDefinition,
    loc: ?Location = null,
};

/// Interface type definition
pub const InterfaceTypeDefinition = struct {
    description: ?StringValue,
    name: Name,
    interfaces: ?[]NamedType,
    directives: ?[]Directive,
    fields: ?[]FieldDefinition,
    loc: ?Location = null,
};

/// Interface type extension
pub const InterfaceTypeExtension = struct {
    name: Name,
    interfaces: ?[]NamedType,
    directives: ?[]Directive,
    fields: ?[]FieldDefinition,
    loc: ?Location = null,
};

/// Union type definition
pub const UnionTypeDefinition = struct {
    description: ?StringValue,
    name: Name,
    directives: ?[]Directive,
    types: ?[]NamedType,
    loc: ?Location = null,
};

/// Union type extension
pub const UnionTypeExtension = struct {
    name: Name,
    directives: ?[]Directive,
    types: ?[]NamedType,
    loc: ?Location = null,
};

/// Enum type definition
pub const EnumTypeDefinition = struct {
    description: ?StringValue,
    name: Name,
    directives: ?[]Directive,
    values: ?[]EnumValueDefinition,
    loc: ?Location = null,
};

/// Enum type extension
pub const EnumTypeExtension = struct {
    name: Name,
    directives: ?[]Directive,
    values: ?[]EnumValueDefinition,
    loc: ?Location = null,
};

/// Input object type definition
pub const InputObjectTypeDefinition = struct {
    description: ?StringValue,
    name: Name,
    directives: ?[]Directive,
    fields: ?[]InputValueDefinition,
    loc: ?Location = null,
};

/// Input object type extension
pub const InputObjectTypeExtension = struct {
    name: Name,
    directives: ?[]Directive,
    fields: ?[]InputValueDefinition,
    loc: ?Location = null,
};

/// Directive definition
pub const DirectiveDefinition = struct {
    description: ?StringValue,
    name: Name,
    arguments: ?[]InputValueDefinition,
    repeatable: bool,
    locations: []DirectiveLocation,
    loc: ?Location = null,
};

/// Field definition
pub const FieldDefinition = struct {
    description: ?StringValue,
    name: Name,
    arguments: ?[]InputValueDefinition,
    type: Type,
    directives: ?[]Directive,
    loc: ?Location = null,
};

/// Input value definition
pub const InputValueDefinition = struct {
    description: ?StringValue,
    name: Name,
    type: Type,
    default_value: ?Value,
    directives: ?[]Directive,
    loc: ?Location = null,
};

/// Enum value definition
pub const EnumValueDefinition = struct {
    description: ?StringValue,
    value: EnumValue,
    directives: ?[]Directive,
    loc: ?Location = null,
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
    union,
    enum,
    enum_value,
    input_object,
    input_field_definition,
};

/// Utility function to create a new document
pub fn newDocument(allocator: std.mem.Allocator, definitions: []Definition) !Document {
    return Document{
        .definitions = try allocator.dupe(Definition, definitions),
    };
}

/// Utility function to create a new name
pub fn newName(value: []const u8) Name {
    return Name{ .value = value };
}

/// Utility function to create a new location
pub fn newLocation(start: usize, end: usize, start_line: usize, start_column: usize, end_line: usize, end_column: usize) Location {
    return Location{
        .start = start,
        .end = end,
        .start_line = start_line,
        .start_column = start_column,
        .end_line = end_line,
        .end_column = end_column,
    };
}

/// Utility function to create a new selection set
pub fn newSelectionSet(allocator: std.mem.Allocator, selections: []Selection) !SelectionSet {
    return SelectionSet{
        .selections = try allocator.dupe(Selection, selections),
    };
}

/// Utility function to create a new field
pub fn newField(allocator: std.mem.Allocator, name: Name, alias: ?Name, arguments: ?[]Argument, directives: ?[]Directive, selection_set: ?SelectionSet) !Field {
    return Field{
        .name = name,
        .alias = alias,
        .arguments = if (arguments) |args| try allocator.dupe(Argument, args) else null,
        .directives = if (directives) |dirs| try allocator.dupe(Directive, dirs) else null,
        .selection_set = selection_set,
    };
}

/// Utility function to create a new operation definition
pub fn newOperationDefinition(allocator: std.mem.Allocator, operation_type: OperationType, name: ?Name, variable_definitions: ?[]VariableDefinition, directives: ?[]Directive, selection_set: SelectionSet) !OperationDefinition {
    return OperationDefinition{
        .operation_type = operation_type,
        .name = name,
        .variable_definitions = if (variable_definitions) |vars| try allocator.dupe(VariableDefinition, vars) else null,
        .directives = if (directives) |dirs| try allocator.dupe(Directive, dirs) else null,
        .selection_set = selection_set,
    };
}

/// Utility function to create a new fragment definition
pub fn newFragmentDefinition(allocator: std.mem.Allocator, name: Name, type_condition: NamedType, directives: ?[]Directive, selection_set: SelectionSet) !FragmentDefinition {
    return FragmentDefinition{
        .name = name,
        .type_condition = type_condition,
        .directives = if (directives) |dirs| try allocator.dupe(Directive, dirs) else null,
        .selection_set = selection_set,
    };
}

/// Utility function to create a new string value
pub fn newStringValue(value: []const u8, block: bool) StringValue {
    return StringValue{
        .value = value,
        .block = block,
    };
}

/// Utility function to create a new int value
pub fn newIntValue(value: []const u8) IntValue {
    return IntValue{ .value = value };
}

/// Utility function to create a new float value
pub fn newFloatValue(value: []const u8) FloatValue {
    return FloatValue{ .value = value };
}

/// Utility function to create a new boolean value
pub fn newBooleanValue(value: bool) BooleanValue {
    return BooleanValue{ .value = value };
}

/// Utility function to create a new null value
pub fn newNullValue() NullValue {
    return NullValue{};
}

/// Utility function to create a new enum value
pub fn newEnumValue(value: Name) EnumValue {
    return EnumValue{ .value = value };
}

/// Utility function to create a new list value
pub fn newListValue(allocator: std.mem.Allocator, values: []Value) !ListValue {
    return ListValue{
        .values = try allocator.dupe(Value, values),
    };
}

/// Utility function to create a new object value
pub fn newObjectValue(allocator: std.mem.Allocator, fields: []ObjectField) !ObjectValue {
    return ObjectValue{
        .fields = try allocator.dupe(ObjectField, fields),
    };
}

/// Utility function to create a new named type
pub fn newNamedType(name: Name) NamedType {
    return NamedType{ .name = name };
}

/// Utility function to create a new directive
pub fn newDirective(allocator: std.mem.Allocator, name: Name, arguments: ?[]Argument) !Directive {
    return Directive{
        .name = name,
        .arguments = if (arguments) |args| try allocator.dupe(Argument, args) else null,
    };
}

/// Utility function to create a new argument
pub fn newArgument(name: Name, value: Value) Argument {
    return Argument{
        .name = name,
        .value = value,
    };
}

/// Utility function to create a new variable
pub fn newVariable(name: Name) Variable {
    return Variable{ .name = name };
}

/// Utility function to create a new variable definition
pub fn newVariableDefinition(allocator: std.mem.Allocator, variable: Variable, type: Type, default_value: ?Value, directives: ?[]Directive) !VariableDefinition {
    return VariableDefinition{
        .variable = variable,
        .type = type,
        .default_value = default_value,
        .directives = if (directives) |dirs| try allocator.dupe(Directive, dirs) else null,
    };
}

/// Utility function to create a new object field
pub fn newObjectField(name: Name, value: Value) ObjectField {
    return ObjectField{
        .name = name,
        .value = value,
    };
}

/// Utility function to create a new fragment spread
pub fn newFragmentSpread(allocator: std.mem.Allocator, name: Name, directives: ?[]Directive) !FragmentSpread {
    return FragmentSpread{
        .name = name,
        .directives = if (directives) |dirs| try allocator.dupe(Directive, dirs) else null,
    };
}

/// Utility function to create a new inline fragment
pub fn newInlineFragment(allocator: std.mem.Allocator, type_condition: ?NamedType, directives: ?[]Directive, selection_set: SelectionSet) !InlineFragment {
    return InlineFragment{
        .type_condition = type_condition,
        .directives = if (directives) |dirs| try allocator.dupe(Directive, dirs) else null,
        .selection_set = selection_set,
    };
}
