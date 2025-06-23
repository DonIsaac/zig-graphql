//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");

pub const lang = struct {
    pub const Lexer = @import("lang/Lexer.zig");
    pub const Parser = @import("lang/Parser.zig");
    pub const Ast = @import("lang/Ast.zig");
};

test {
    std.testing.refAllDecls(@This());
}
