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
const Ast = @import("../Ast.zig");

_: u0,

pub fn init(proof: *const ParserImpl) AstBuilder {
    comptime if (@FieldType(ParserImpl, "ast") != AstBuilder) {
        @compileError("p.ast does not exist or is not an AstBuilder");
    };

    _ = proof;
    return .{ ._ = @as(u8, 0) };
}

fn parser(self: *const AstBuilder) *const ParserImpl {
    return @alignCast(@fieldParentPtr("ast", self));
}

/// Create an `Ast.Type` node from some inner `Ast.Type.*`
pub fn @"type"(self: *AstBuilder, ty: anytype) ParserImpl.Error!Ast.Type {
    const p = self.parser();
    return switch (@TypeOf(ty)) {
        Ast.Type.List => Ast.Type{ .list = try p.create(ty) },
        Ast.Type.Named => Ast.Type{ .named = try p.create(ty) },
        Ast.Type.NonNull => Ast.Type{ .non_null = try p.create(ty) },
        else => {
            @branchHint(.cold);
            @compileError("unsupported type node: " ++ @typeName(@TypeOf(ty)));
        },
    };
}
