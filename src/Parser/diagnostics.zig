const std = @import("std");
const util = @import("../util.zig");
const Token = @import("../Lexer.zig").Token;
const Diagnostic = @import("../Diagnostic.zig");
const Span = @import("../Span.zig");

/// `Fragments cannot be named 'on'`
pub fn fragmentNameCannotBeOn(tok: Token) Diagnostic {
    util.debugAssert(tok.kind == .kw_on);
    return Diagnostic{
        .message = "Fragments cannot be named 'on'",
        .span = tok.span,
    };
}

pub inline fn variableInConstValueContext(span: Span) Diagnostic {
    return Diagnostic{
        .message = "Variables cannot be used here, only constant values",
        .span = span,
    };
}

pub fn listCannotBeEmpty(comptime name_plural: []const u8, span: Span) Diagnostic {
    comptime {
        std.debug.assert(name_plural.len > 0);
        // name cannot have trailing whitespace
        std.debug.assert(!std.mem.endsWith(u8, name_plural, &std.ascii.whitespace));
    }

    return Diagnostic{
        .message = name_plural ++ " must have at least one item",
        .span = span,
    };
}
