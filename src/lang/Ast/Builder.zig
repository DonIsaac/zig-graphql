//! A ZST that helps construct AST nodes.
//!
//! This may only ever be created by a `ParserImpl` and called as a property
//! on instances of that type.
//!
//! ## Note
//! This code uses cursed Zig fuckery of the highest order, but boy does it
//! produce a nice API.
const Builder = @This();
const std = @import("std");
const ParserImpl = @import("../Parser/ParserImpl.zig");
const Ast = @import("../Ast.zig");
const Span = @import("../../Span.zig");
const Allocator = std.mem.Allocator;

_: u0,

pub fn init(proof: *const ParserImpl) Builder {
    comptime if (@FieldType(ParserImpl, "ast") != Builder) {
        @compileError("p.ast does not exist or is not an AstBuilder");
    };

    _ = proof;
    return .{ ._ = @as(u0, 0) };
}

// =============================================================================

fn parser(self: *const Builder) *const ParserImpl {
    return @alignCast(@fieldParentPtr("ast", self));
}

// misc

pub inline fn slice(self: *const Builder, spannable: anytype) []const u8 {
    return Span.spanned(spannable).slice(self.parser().source());
}

// ================================ ALLOCATIONS ================================

pub inline fn allocator(self: *const Builder) Allocator {
    return self.parser().allocator();
}

/// Allocate a new AST node.
pub fn alloc(
    self: *const Builder,
    ast_node: anytype,
) Allocator.Error!*@TypeOf(ast_node) {
    const T = @TypeOf(ast_node);
    const ptr: *T = try self.allocator().create(T);
    ptr.* = ast_node;
    return ptr;
}

/// Allocate a new list of AST nodes.
pub inline fn list(
    self: *const Builder,
    /// Type of AST nodes the list is of
    comptime T: type,
    /// Initial capacity of the list
    comptime capacity: usize,
) Allocator.Error!std.ArrayList(T) {
    return std.ArrayList(T).initCapacity(self.allocator(), capacity);
}

/// Convert a list of AST nodes into a slice, reclaiming unused memory if
/// possible. Caller owns the returned allocation.
///
/// Some caveats:
/// - `list_` cannot be freed after calling this function. In some cases, freeing will be a no-op, but in others
///   it will invalidate the returned slice's allocation.
/// - the returned slice can and should be freed after use.
pub fn intoSlice(self: *const Builder, T: type, list_: *std.ArrayList(T)) Allocator.Error![]T {
    const gpa = self.allocator();

    if (self.parser().options.lossless) {
        // fully reclaims unused memory if resizing isnt possible
        return list_.toOwnedSlice(gpa);
    }

    // attempt to resize the list's buffer in-place. If resizing would require
    // a reallocation + copy, we'll leak the memory
    _ = gpa.resize(list_.allocatedSlice(), list_.items.len);
    return list_.items;
}

// ================================= BUILDERS ==================================

/// Create a `Name` token covering some thing that can be spanned (via `Span.spanned`)
pub fn name(self: *const Builder, span_like_thingy: anytype) Ast.Name {
    const span = Span.spanned(span_like_thingy);
    const slice_ = span.slice(self.parser().source());
    return Ast.Name{ .value = slice_, .pos = span.offset(.Start) };
}
pub fn namedType(self: *const Builder, span_like_thingy: anytype) Ast.Type.Named {
    const name_ = self.name(span_like_thingy);
    return Ast.Type.Named{ .name = name_ };
}

/// Create an `Ast.Type` node from some inner `Ast.Type.*`
pub fn @"type"(self: *const Builder, ty: anytype) Allocator.Error!Ast.Type {
    return switch (@TypeOf(ty)) {
        Ast.Type.List => Ast.Type{ .list = try self.alloc(ty) },
        Ast.Type.Named => Ast.Type{ .named = try self.alloc(ty) },
        Ast.Type.NonNull => Ast.Type{ .non_null = try self.alloc(ty) },
        Ast.Type => ty,
        else => {
            @branchHint(.cold);
            @compileError("unsupported type node: " ++ @typeName(@TypeOf(ty)));
        },
    };
}

// values

// definitions

pub inline fn anonymousOperationDefinition(_: *const Builder, selection_set: Ast.Selection.Set) Ast.Operation.Definition {
    return Ast.Operation.Definition{
        .operation_type = .query,
        .name = null,
        .directives = &[_]Ast.Directive{},
        .variable_definitions = &[_]Ast.Variable.Definition{},
        .selection_set = selection_set,
        .span = selection_set.span,
    };
}

pub inline fn selectionFragmentSpread(
    _: *const Builder,
    fragment_name: Ast.Name,
    directives: []Ast.Directive,
    span: Span,
) Ast.Selection {
    return Ast.Selection{ .fragment_spread = .{
        .name = fragment_name,
        .directives = directives,
        .span = span,
    } };
}

pub inline fn selectionInlineFragment(
    _: *const Builder,
    type_condition: ?Ast.Type.Named,
    directives: []Ast.Directive,
    selection_set: Ast.Selection.Set,
    span: Span,
) Ast.Selection {
    return Ast.Selection{ .inline_fragment = .{
        .type_condition = type_condition,
        .directives = directives,
        .selection_set = selection_set,
        .span = span,
    } };
}

pub inline fn selectionInlineFragmentSelectionOnly(_: *const Builder, selection_set: Ast.Selection.Set) Ast.Selection {
    return Ast.Selection{ .inline_fragment = .{
        .type_condition = null,
        .directives = &[_]Ast.Directive{},
        .selection_set = selection_set,
        .span = selection_set.span,
    } };
}
