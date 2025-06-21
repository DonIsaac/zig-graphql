const builtin = @import("builtin");
const std = @import("std");
const CallingConvention = std.builtin.CallingConvention;

pub const is_debug = builtin.mode == .Debug or builtin.is_test;

pub const callconv_inline: CallingConvention = if (builtin.mode == .Debug)
    .auto
else
    .@"inline";

pub inline fn debugAssert(ok: bool) void {
    if (comptime !is_debug) {
        if (@inComptime()) std.debug.assert(ok);
    } else {
        std.debug.assert(ok);
    }
}
