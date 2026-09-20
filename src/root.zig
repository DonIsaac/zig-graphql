//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");

/// Corresponds to the
/// [language](https://spec.graphql.org/draft/#sec-Language) section of the
/// GraphQL specification.
pub const lang = struct {
    pub const Parser = @import("lang/Parser.zig");
    pub const Ast = @import("lang/Ast.zig");
};

pub const Diagnostic = @import("Diagnostic.zig");
pub const Span = @import("Span.zig");

test {
    std.testing.refAllDecls(lang);
    _ = @import("test/ast_regression.zig");
}
