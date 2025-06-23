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
        .null_value => .{ .null = .init(tok.span) },
        inline .kw_true, .kw_false => |v| Value{ .boolean = try parseBoolean(p, v == .kw_true) },
        .l_bracket => @panic("todo: ListValue[?Const]"),
        .l_curly => @panic("todo: ObjectValue[?Const]"),
        .int_value => blk: {
            try p.bump();
            break :blk Value{ .int = .{ .value = p.ast.slice(tok), .span = tok.span } };
        },
        .name => blk: {
            try p.bump();
            break :blk Value{ .@"enum" = .{ .value = p.ast.name(tok) } };
        },
        else => p.unexpectedToken(),
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
    try p.expect(.dollar);
    const name = try p.parseName();
    return Ast.Variable{ .name = name, .span = p.endSpan(start) };
}

inline fn parseBoolean(p: *ParserImpl, comptime value: bool) !Ast.Value.Boolean {
    const t = p.cur;
    util.debugAssert(t.kind == .kw_true or t.kind == .kw_false);
    try p.bump();

    return Value.Boolean{ .pos = t.startOffset(), .value = value };
}
