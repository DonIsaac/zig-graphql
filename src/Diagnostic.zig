const Diagnostic = @This();

span: Span,
message: []const u8,

pub inline fn init(span: Span, message: []const u8) Diagnostic {
    return .{ .span = span, .message = message };
}

const Span = @import("Span.zig");
