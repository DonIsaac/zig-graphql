const ParserImpl = @import("ParserImpl.zig");
const Ast = @import("../Ast.zig");
const expressions = @import("expressions.zig");

pub fn parseType(self: *ParserImpl) !Ast.Type {
    const start = self.startSpan();
    if (self.at(.l_bracket)) {
        const ty = try parseListType(self);
        return if (self.at(.bang)) {
            const span = self.endSpan(start);
            try self.bump();
            return allocType(self, Ast.Type.NonNull{ .type = try allocType(self, ty), .span = span });
        } else {
            return allocType(self, ty);
        };
    }

    const ty = try parseNamedType(self);
    const span = self.endSpan(start);
    if (self.at(.bang)) {
        try self.bump();
        return allocType(self, Ast.Type.NonNull{ .type = try allocType(self, ty), .span = span });
    }

    return allocType(self, ty);
}

pub fn parseNamedType(self: *ParserImpl) ParserImpl.Error!Ast.Type.Named {
    return .{ .name = try expressions.parseName(self) };
}

/// `[Type]`
fn parseListType(self: *ParserImpl) ParserImpl.Error!Ast.Type.List {
    try self.expect(.l_bracket);
    const start = self.startSpan();
    const ty = try parseType(self);
    const span = self.endSpan(start);
    try self.expect(.r_bracket);

    return Ast.Type.List{ .type = ty, .span = span };
}

fn parseNamedOrListType(parser: *ParserImpl) ParserImpl.Error!Ast.Type {
    return if (parser.at(.l_bracket))
        parseListType(parser)
    else
        parseNamedType(parser);
}

fn allocType(self: *ParserImpl, ty: anytype) ParserImpl.Error!Ast.Type {
    return switch (@TypeOf(ty)) {
        Ast.Type.List => Ast.Type{ .list = try self.alloc(ty) },
        Ast.Type.Named => Ast.Type{ .named = try self.alloc(ty) },
        Ast.Type.NonNull => Ast.Type{ .non_null = try self.alloc(ty) },
        else => {
            @branchHint(.cold);
            @compileError("unsupported type node: " ++ @typeName(@TypeOf(ty)));
        },
    };
}

const std = @import("std");
const t = std.testing;

test parseListType {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var parser = ParserImpl.init(t.allocator, "[Int]");
    // parser.peek();
    try parser.bump();
    const ty = parseListType(&parser) catch |e| {
        for (parser.errors()) |err| {
            std.debug.print("{}: {s}\n", .{ err.span.start, err.message });
        }
        return e;
    };
    try t.expectEqualStrings("Int", ty.type.named.name.value);
}
