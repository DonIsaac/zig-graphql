const builtin = @import("builtin");
const std = @import("std");

const CallingConvention = std.builtin.CallingConvention;
pub const callconv_inline: CallingConvention = if (builtin.mode == .Debug) // intentionally not is_debug
    .auto
else
    .@"inline";

pub const is_debug: bool = builtin.mode == .Debug or builtin.is_test;
pub const assert_enabled: bool = switch (builtin.mode) {
    .ReleaseFast, .ReleaseSmall => false,
    else => true,
};

pub inline fn debugAssert(ok: bool) void {
    if (comptime !is_debug) {
        if (@inComptime()) std.debug.assert(ok);
    } else {
        std.debug.assert(ok);
    }
}
