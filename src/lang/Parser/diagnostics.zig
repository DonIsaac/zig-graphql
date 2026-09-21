const std = @import("std");
const util = @import("../../util.zig");
const Token = @import("../Lexer.zig").Token;
const Diagnostic = @import("../../Diagnostic.zig");
const Span = @import("../../Span.zig");

/// `Fragments cannot be named 'on'`
pub fn fragmentNameCannotBeOn(tok: Token) Diagnostic {
    @branchHint(.cold);
    util.debugAssert(tok.kind == .kw_on);
    return Diagnostic{
        .message = "Fragments cannot be named 'on'",
        .span = tok.span,
    };
}

/// `Type conditions must name a type`
pub fn typeConditionIsMissingAType(tok: Token) Diagnostic {
    @branchHint(.cold);
    util.debugAssert(tok.kind == .kw_on);
    return Diagnostic{
        .message = "Type conditions must name a type",
        .span = tok.span,
    };
}

/// `Unknown directive location`
pub fn unknownDirectiveLocation(tok: Token) Diagnostic {
    @branchHint(.cold);
    return Diagnostic{
        .message = "Unknown directive location",
        .span = tok.span,
    };
}

pub inline fn variableInConstValueContext(span: Span) Diagnostic {
    @branchHint(.cold);
    return Diagnostic{
        .message = "Variables cannot be used here, only constant values",
        .span = span,
    };
}

pub fn listCannotBeEmpty(comptime name_plural: []const u8, span: Span) Diagnostic {
    @branchHint(.cold);
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

pub fn argumentCannotBeVariable(tok: Token) Diagnostic {
    @branchHint(.cold);
    return Diagnostic{
        // TODO: add help field to Diagnostic
        .message = "Arguments cannot be variables. Remove the `$` prefix",
        .span = tok.span,
    };
}
