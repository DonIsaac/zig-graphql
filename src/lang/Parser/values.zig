const std = @import("std");
const util = @import("../../util.zig");
const ParserImpl = @import("ParserImpl.zig");
const Ast = @import("../Ast.zig");
const diagnostics = @import("diagnostics.zig");

const Value = Ast.Value;

///    Value[Const] :
///        [~Const] Variable
///        IntValue
///        FloatValue
///        StringValue
///        BooleanValue
///        NullValue
///        EnumValue
///        ListValue[?Const]
///        ObjectValue[?Const]
pub fn parseValue(p: *ParserImpl, comptime is_const: bool) ParserImpl.Error!Ast.Value {
    const start = p.startSpan();
    const tok = p.cur;
    return switch (tok.kind) {
        // $name
        .dollar => if (is_const) blk: {
            try p.assert(.dollar);
            try p.bump();
            p.report(diagnostics.variableInConstValueContext(p.endSpan(start)));
            break :blk ParserImpl.Error.UnexpectedToken;
        } else Value{ .variable = try parseVariable(p) },
        .kw_null => .{ .null = .init(tok.span) },
        inline .kw_true, .kw_false => |v| Value{ .boolean = try parseBoolean(p, v == .kw_true) },
        .l_bracket => @panic("todo: ListValue[?Const]"),
        .l_curly => @panic("todo: ObjectValue[?Const]"),
        .string_value, .block_string_value => .{ .string = try parseStringValue(p) },
        .int_value => blk: {
            try p.bump();
            break :blk Value{ .int = .{ .value = p.ast.slice(tok), .span = tok.span } };
        },
        // EnumValue : Name but not `true`, `false` or `null`, each of which is
        // matched above
        else => if (tok.kind.isName()) blk: {
            try p.bump();
            break :blk Value{ .@"enum" = .{ .value = p.ast.name(tok) } };
        } else p.unexpectedToken(),
    };
}

pub fn parseVariable(p: *ParserImpl) !Ast.Variable {

    // TODO: this technically allows for productions like
    // - `$,,,name`
    // - `$
    //    # wow im a comment
    //    foobar`
    //
    // According to the GraphQL spec, Variable is not a lexical production, (I
    // don't think, TODO verify) and commas/etc are ignored, so maybe it's still
    // valid?
    const start = p.startSpan();
    _ = try p.expect(.dollar);
    const name = try p.parseName();
    return Ast.Variable{ .name = name, .span = p.endSpan(start) };
}

inline fn parseBoolean(p: *ParserImpl, comptime value: bool) !Ast.Value.Boolean {
    const t = p.cur;
    util.debugAssert(t.kind == .kw_true or t.kind == .kw_false);
    try p.bump();

    return Value.Boolean{ .pos = t.startOffset(), .value = value };
}

pub fn parseStringValue(p: *ParserImpl) ParserImpl.Error!Ast.Value.String {
    const cur = p.cur;
    const block = switch (cur.kind) {
        .block_string_value => true,
        .string_value => false,
        else => return p.expectedToken("a string value"),
    };
    const slice = cur.span.slice(p.source());
    try p.bump();
    return .{ .value = slice, .span = cur.span, .block = block };
}

test parseStringValue {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const Case = struct { src: []const u8, block: bool = false };
    inline for ([_]Case{
        .{ .src = "\"foo\"" },
        .{
            .block = true,
            .src =
            \\"""
            \\foo
            \\"""
            ,
        },
    }) |case| {
        defer _ = arena.reset(.retain_capacity);

        var p = ParserImpl.init(arena.allocator(), case.src);
        try p.bump();
        errdefer {
            std.debug.print("Test failed for case: \n{s}\n", .{case.src});
            for (p.errors()) |err| {
                std.debug.print("{f}\n\n", .{err});
            }
        }
        const actual = try parseStringValue(&p);
        try std.testing.expectEqual(case.block, actual.block);
        try std.testing.expectEqualStrings(actual.value, case.src);
    }
}
