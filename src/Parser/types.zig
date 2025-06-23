const ParserImpl = @import("ParserImpl.zig");
const Ast = @import("../Ast.zig");
const expressions = @import("expressions.zig");

pub fn parseType(p: *ParserImpl) !Ast.Type {
    const start = p.startSpan();
    const ty = try parseNamedOrListType(p);
    //    NonNullType :
    //        ListType `!`
    //        NamedType `!`
    _ = try p.eat(.bang) orelse return ty;
    const span = p.endSpan(start);
    // return allocType(p, Ast.Type.NonNull{ .type = ty, .span = span });
    return p.ast.type(Ast.Type.NonNull{ .type = ty, .span = span });
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

fn parseNamedOrListType(p: *ParserImpl) ParserImpl.Error!Ast.Type {
    return if (p.at(.l_bracket)) |_| list: {
        const ty = try parseListType(p);
        p.assertNotWithoutAdvance(.r_bracket); // list parser should consume `]`
        break :list p.ast.type(ty);
    } else p.ast.type(try parseNamedType(p));
}

const std = @import("std");
const t = std.testing;

test parseListType {
    const Span = @import("../Span.zig");

    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var parser = ParserImpl.init(arena.allocator(), "[Int]");
    // parser.peek();
    try parser.bump();
    const ty = parseListType(&parser) catch |e| {
        for (parser.errors()) |err| {
            std.debug.print("{}: {s}\n", .{ err.span.start, err.message });
        }
        return e;
    };
    try t.expect(ty.type == .named);
    try t.expectEqual(
        Span{ .start = 1, .end = 5 }, // FIXME: should be 4. Same bug as "Int]"
        ty.type.named.name.span(),
    );
    // FIXME: Should be "Int"
    try t.expectEqualStrings("Int]", ty.type.named.name.value);
}
