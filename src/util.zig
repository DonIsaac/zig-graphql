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

/// Invokes detectable illegal behavior when `ok` is `false`.
///
/// Checks only occur in debug and test builds. Expressions passed as an argument
/// may not be stripped by the optimizer, so only pass cheap values. Guard
/// expensive values behind `is_debug`.
///
/// ```
/// const util = @import("util.zig");
///
/// if (util.is_debug) {
///    const expensive_value = doThing();
///    std.debug.assert(expensive_value > 0);
/// }
/// ```
pub inline fn debugAssert(ok: bool) void {
    if (comptime !is_debug) {
        if (@inComptime()) std.debug.assert(ok);
    } else {
        std.debug.assert(ok);
    }
}
