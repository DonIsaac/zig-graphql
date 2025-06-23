const std = @import("std");
const util = @import("util");
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
    return switch (p.cur.kind) {
        // $name
        .dollar => if (is_const) blk: {
            try p.assert(.dollar);
            try p.bump();
            p.report(diagnostics.variableInConstValueContext(p.endSpan(start)));
            break :blk ParserImpl.Error.UnexpectedToken;
        } else Value{ .variable = try parseVariable(p) },
        .null_value => .null,
        inline .kw_true, .kw_false => |v| try parseBoolean(p, v == .kw_true),
        // .kw_true => Value{ .@"enum" = .}
        else => p.unexpectedToken(),
    };
}

pub fn parseVariable(p: *ParserImpl) Ast.Variable {

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

inline fn parseBoolean(p: *ParserImpl, comptime value: bool) Ast.Value.Boolean {
    const t = p.cur;
    util.debugAssert(t.kind == .kw_true or t.kind == .kw_false);
    p.bump();

    return Value.boolean{ .pos = t.span.offset(.Start), .value = value };
}
