const Diagnostic = @This();

span: Span,
message: []const u8,

const Span = @import("Span.zig");
