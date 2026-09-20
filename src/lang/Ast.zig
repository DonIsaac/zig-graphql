//! GraphQL AST data structure
const Span = @import("../Span.zig");

pub const Builder = @import("Ast/Builder.zig");

/// Represents a complete GraphQL document
///
/// ## References
/// - [2.2 Document](https://spec.graphql.org/draft/#sec-Document)
pub const Document = struct {
    definitions: []Definition,
    span: Span,

    pub fn isExecutable(self: *const Document) bool {
        if (self.definitions.len == 0) return false;
        var has_operation = false;
        for (self.definitions) |def| {
            switch (def) {
                .executable => |exe| has_operation = has_operation or exe == .operation,
                else => return false,
            }
        }
        return has_operation;
    }
};

pub const Executable = struct {
    /// An executable document
    pub const Document = struct {
        definitions: []Executable.Definition,
        span: Span,

        pub fn isExecutable(self: *const Executable.Document) bool {
            return self.definitions.len > 0 and for (self.definitions) |def| blk: {
                if (def == .operation) break :blk true;
            } else false;
        }
    };

    /// An executable definition (operation or fragment)
    pub const Definition = union(enum) {
        operation: Operation.Definition,
        fragment: FragmentDefinition,
    };
};

/// A definition in a GraphQL document
pub const Definition = union(enum) {
    executable: Executable.Definition,
    type_system: TypeSystem.DefinitionOrExtension,
};

/// A GraphQL operation (query, mutation, or subscription)
///
/// ## References
/// - [2.3 Operations](https://spec.graphql.org/draft/#sec-Language.Operations)
pub const Operation = struct {
    pub const Definition = struct {
        operation_type: Operation.Type,
        name: ?Name,
        variable_definitions: []Variable.Definition,
        directives: []Directive,
        selection_set: Selection.Set,
        span: Span,
    };

    /// The type of operation
    pub const Type = enum {
        /// A read-only fetch
        query,
        /// A write followed by a fetch
        mutation,
        /// A long-lived request that fetches data in response to a sequence of
        /// events over time
        subscription,
    };
};

/// A selection in a selection set
///
/// ## References
/// - [2.4 Selection Sets](https://spec.graphql.org/draft/#sec-Selection-Sets)
pub const Selection = union(enum) {
    field: Field,
    fragment_spread: FragmentSpread,
    inline_fragment: InlineFragment,

    /// A selection set defines an ordered set of selections (fields, fragment
    /// spreads and inline fragments) against an object, union or interface
    /// type.
    ///
    /// ## References
    /// - [2.4 Selection Sets](https://spec.graphql.org/draft/#sec-Selection-Sets)
    pub const Set = struct {
        selections: []Selection,
        span: Span,
        pub const empty: Selection.Set = .{ .selections = &[_]Selection{}, .span = .empty };
    };

    /// A field selection
    ///
    /// ## References
    /// - [2.5 Fields](https://spec.graphql.org/draft/#sec-Language.Fields)
    pub const Field = struct {
        alias: ?Name,
        name: Name,
        arguments: ?Argument.List,
        directives: ?[]Directive,
        selection_set: ?Selection.Set,
        span: Span,
    };

    /// A fragment spread
    pub const FragmentSpread = struct {
        name: Name,
        directives: []Directive,
        span: Span,
    };

    /// An inline fragment
    pub const InlineFragment = struct {
        type_condition: ?Type.Named,
        directives: []Directive,
        selection_set: Selection.Set,
        span: Span,
    };
};

/// A fragment definition
pub const FragmentDefinition = struct {
    name: Name,
    type_condition: Type.Named,
    directives: ?[]Directive,
    selection_set: Selection.Set,
    span: Span,
};

/// A variable reference
pub const Variable = struct {
    name: Name,
    span: Span,

    /// A variable definition
    pub const Definition = struct {
        variable: Variable,
        type: Type,
        default_value: ?Value,
        directives: ?[]Directive,
        span: Span,
    };
};

/// A field argument
///
/// ## References
/// - [2.6 Arguments](https://spec.graphql.org/draft/#sec-Language.Arguments)
pub const Argument = struct {
    name: Name,
    value: Value,
    span: Span,

    /// A list of arguments
    ///
    /// ## References
    /// - [2.6 Arguments](https://spec.graphql.org/draft/#sec-Language.Arguments)
    pub const List = struct {
        args: []Argument,
        span: Span,
        pub const empty: List = .{ .args = &[_]Argument{}, .span = .empty };
    };
};

/// A directive
pub const Directive = struct {
    name: Name,
    arguments: ?[]Argument,
    span: Span,
};

/// A GraphQL value
///
/// ## References
/// - [2.9 Input Values](https://spec.graphql.org/draft/#sec-Input-Values)
pub const Value = union(enum) {
    variable: Variable,
    int: Int,
    float: Float,
    string: String,
    boolean: Boolean,
    null: Null,
    @"enum": Enum,
    list: List,
    object: Object,

    /// An integer value
    pub const Int = struct {
        value: []const u8,
        span: Span,
    };

    /// A float value
    pub const Float = struct {
        value: []const u8,
        span: Span,
    };

    /// A string value
    pub const String = struct {
        value: []const u8,
        block: bool, // true for block strings ("""), false for regular strings
        span: Span,
    };

    /// A boolean value
    pub const Boolean = struct {
        value: bool,
        pos: Span.Offset,
        pub inline fn span(self: Boolean) Span {
            return if (self.value)
                self.pos.keywordSpan("true")
            else
                self.pos.keywordSpan("false");
        }
    };

    /// A null value
    pub const Null = struct {
        pos: Span.Offset,
        pub inline fn init(span_: Span) Null {
            return .{ .pos = span_.offset(.Start) };
        }
        pub inline fn span(self: Null) Span {
            return self.pos.keywordSpan("null");
        }
    };

    /// An enum value
    pub const Enum = struct {
        value: Name,
    };

    /// A list value
    pub const List = struct {
        values: []Value,
        span: Span,
    };

    /// An object value
    pub const Object = struct {
        fields: []Object.Field,
        span: Span,
        /// A field in an object value
        pub const Field = struct {
            name: Name,
            value: Value,
            span: Span,
        };
    };
};

/// A GraphQL type reference
///
/// See: [2.11 Type References](https://spec.graphql.org/draft/#sec-Type-References)
pub const Type = union(enum) {
    named: *Type.Named,
    list: *Type.List,
    non_null: *Type.NonNull,

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
    ///
    /// `NamedType` in the spec
    pub const Named = struct {
        name: Name,
    };
};

/// A name token
pub const Name = struct {
    value: []const u8,
    pos: Span.Offset,
    pub inline fn span(self: Name) Span {
        return self.pos.spanSized(@intCast(self.value.len));
    }
};

/// A type system document
pub const TypeSystem = struct {
    definitions: []TypeSystem.DefinitionOrExtension,
    span: Span,

    /// Type system definitions and extensions
    pub const DefinitionOrExtension = union(enum) {
        definition: TypeSystem.Definition,
        extension: TypeSystem.Extension,
    };

    /// Type system definitions
    pub const Definition = union(enum) {
        schema: Schema.Definition,
        scalar: ScalarType.Definition,
        object: ObjectTypeDefinition,
        interface: InterfaceTypeDefinition,
        @"union": UnionTypeDefinition,
        @"enum": EnumTypeDefinition,
        input_object: InputObjectTypeDefinition,
        directive: DirectiveDefinition,
    };

    /// Type system extensions
    pub const Extension = union(enum) {
        schema: Schema.Extension,
        scalar: ScalarType.Extension,
        object: ObjectTypeExtension,
        interface: InterfaceTypeExtension,
        @"union": UnionTypeExtension,
        @"enum": EnumTypeExtension,
        input_object: InputObjectTypeExtension,
    };
};

pub const Schema = struct {
    /// Schema definition
    pub const Definition = struct {
        description: ?Value.String,
        directives: ?[]Directive,
        operation_types: []RootOperationTypeDefinition,
        span: Span,
    };

    /// Schema extension
    pub const Extension = struct {
        directives: ?[]Directive,
        operation_types: ?[]RootOperationTypeDefinition,
        span: Span,
    };
};

/// Root operation type definition
pub const RootOperationTypeDefinition = struct {
    operation_type: Operation.Type,
    type: Type.Named,
    span: Span,
};

pub const ScalarType = struct {
    /// Scalar type definition
    pub const Definition = struct {
        description: ?Value.String,
        name: Name,
        directives: ?[]Directive,
        span: Span,
    };

    /// Scalar type extension
    pub const Extension = struct {
        name: Name,
        directives: ?[]Directive,
        span: Span,
    };
};

/// Object type definition
pub const ObjectTypeDefinition = struct {
    description: ?Value.String,
    name: Name,
    interfaces: ?[]Type.Named,
    directives: ?[]Directive,
    fields: ?[]FieldDefinition,
    span: Span,
};

/// Object type extension
pub const ObjectTypeExtension = struct {
    name: Name,
    interfaces: ?[]Type.Named,
    directives: ?[]Directive,
    fields: ?[]FieldDefinition,
    span: Span,
};

/// Interface type definition
pub const InterfaceTypeDefinition = struct {
    description: ?Value.String,
    name: Name,
    interfaces: ?[]Type.Named,
    directives: ?[]Directive,
    fields: ?[]FieldDefinition,
    span: Span,
};

/// Interface type extension
pub const InterfaceTypeExtension = struct {
    name: Name,
    interfaces: ?[]Type.Named,
    directives: ?[]Directive,
    fields: ?[]FieldDefinition,
    span: Span,
};

/// Union type definition
pub const UnionTypeDefinition = struct {
    description: ?Value.String,
    name: Name,
    directives: ?[]Directive,
    types: ?[]Type.Named,
    span: Span,
};

/// Union type extension
pub const UnionTypeExtension = struct {
    name: Name,
    directives: ?[]Directive,
    types: ?[]Type.Named,
    span: Span,
};

/// Enum type definition
/// TODO: parse
pub const EnumTypeDefinition = struct {
    description: ?Value.String,
    name: Name,
    directives: ?[]Directive,
    values: ?[]EnumValueDefinition,
    span: Span,
};

/// Enum type extension
pub const EnumTypeExtension = struct {
    name: Name,
    directives: ?[]Directive,
    values: ?[]EnumValueDefinition,
    span: Span,
};

/// Input object type definition
pub const InputObjectTypeDefinition = struct {
    description: ?Value.String,
    name: Name,
    directives: ?[]Directive,
    fields: ?[]InputValueDefinition,
    span: Span,
};

/// Input object type extension
pub const InputObjectTypeExtension = struct {
    name: Name,
    directives: ?[]Directive,
    fields: ?[]InputValueDefinition,
    span: Span,
};

/// Directive definition
pub const DirectiveDefinition = struct {
    description: ?Value.String,
    name: Name,
    arguments: ?[]InputValueDefinition,
    repeatable: bool,
    locations: []DirectiveLocation,
    span: Span,
};

/// Field definition
pub const FieldDefinition = struct {
    description: ?Value.String,
    name: Name,
    arguments: ?[]InputValueDefinition,
    type: Type,
    directives: ?[]Directive,
    span: Span,
};

/// Input value definition
pub const InputValueDefinition = struct {
    description: ?Value.String,
    name: Name,
    type: Type,
    default_value: ?Value,
    directives: ?[]Directive,
    span: Span,
};

/// Enum value definition
pub const EnumValueDefinition = struct {
    description: ?Value.String,
    value: Value.Enum,
    directives: ?[]Directive,
    span: Span,
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
