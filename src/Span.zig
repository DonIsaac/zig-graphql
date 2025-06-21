const Span = @This();

/// Start position from the beginning of the source text
start: u32,
/// End position
end: u32,

pub const empty = Span{ .start = 0, .end = 0 };

pub fn eql(self: Span, other: Span) bool {
    return self.start == other.start and self.end == other.end;
}

pub const Optional = struct {
    _raw: Span,
    pub fn init(span: ?Span) Span.Optional {
        return .{ ._raw = span orelse empty };
    }
    pub fn into(self: Span.Optional) ?Span {
        if (self._raw.eql(empty)) return null;
        return self._raw;
    }
    pub fn unwrap(self: Span.Optional) Span {
        std.debug.assert(!self._raw.eql(empty));
        return self._raw;
    }
};

const std = @import("std");
