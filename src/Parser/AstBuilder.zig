//! A ZST that helps construct AST nodes.
//!
//! This may only ever be created by a `ParserImpl` and called as a property
//! on instances of that type.
//!
//! ## Note
//! This code uses cursed Zig fuckery of the highest order, but boy does it
//! produce a nice API.
const AstBuilder = @This();
const ParserImpl = @import("ParserImpl.zig");
const Token = @import("../Lexer.zig").Token;
const Ast = @import("../Ast.zig");
const Span = @import("../Span.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;

_: u0,

pub fn init(proof: *const ParserImpl) AstBuilder {
    comptime if (@FieldType(ParserImpl, "ast") != AstBuilder) {
        @compileError("p.ast does not exist or is not an AstBuilder");
    };

    _ = proof;
    return .{ ._ = @as(u8, 0) };
}

// =============================================================================

fn parser(self: *const AstBuilder) *const ParserImpl {
    return @alignCast(@fieldParentPtr("ast", self));
}

// ================================ ALLOCATIONS ================================

pub fn allocator(self: *const AstBuilder) Allocator {
    return self.parser().lexer._impl.allocator;
}

pub fn alloc(
    self: *const AstBuilder,
    ast_node: anytype,
) Allocator.Error!*@TypeOf(ast_node) {
    const T = @TypeOf(ast_node);
    const ptr: *T = try self.allocator().create(T);
    ptr.* = ast_node;
    return ptr;
}

pub inline fn list(
    self: *const AstBuilder,
    /// Type of AST nodes the list is of
    comptime T: type,
    comptime capacity: usize,
) Allocator.Error!std.ArrayList(T) {
    return std.ArrayList(T).initCapacity(self.allocator(), capacity);
}

// ================================= BUILDERS ==================================

/// Create a `Name` token covering some thing that can be spanned (via `Span.spanned`)
pub fn name(self: *const AstBuilder, span_like_thingy: anytype) Ast.Name {
    const span = Span.spanned(span_like_thingy);
    const slice = span.slice(self.parser().lexer.source());
    return Ast.Name{ .value = slice, .pos = span.offset(.Start) };
}

/// Create an `Ast.Type` node from some inner `Ast.Type.*`
pub fn @"type"(self: *const AstBuilder, ty: anytype) Allocator.Error!Ast.Type {
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
