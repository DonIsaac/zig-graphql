const Diagnostic = @This();

span: Span,
message: []const u8,

pub inline fn init(span: Span, message: []const u8) Diagnostic {
    return .{ .span = span, .message = message };
}

pub fn format(diag: *const Diagnostic, w: *std.Io.Writer) std.Io.Writer.Error!void {
    return w.writeAll(diag.message);
}

const std = @import("std");
const Span = @import("Span.zig");
