const Span = @This();

/// Start position from the beginning of the source text
start: u32,
/// End position
end: u32,

pub const empty = Span{ .start = 0, .end = 0 };

/// Create a Span starting at some position that is `size` bytes long
pub fn sized(start: u32, size: u32) Span {
    return .{ .start = start, .end = start + size };
}

pub fn eql(self: Span, other: Span) bool {
    return self.start == other.start and self.end == other.end;
}

pub fn len(self: Span) u32 {
    std.debug.assert(self.start <= self.end);
    return self.end - self.start;
}

pub fn slice(self: Span, text: []const u8) []const u8 {
    std.debug.assert(self.start <= self.end);
    return text[self.start..self.end];
}

pub fn spanned(thing: anytype) Span {
    const T = @TypeOf(thing);
    if (T == Span) return thing;
    if (T == Span.Optional) return Span.Optional.unwrap(thing);

    return switch (@typeInfo(T)) {
        .Pointer => |info| switch (info.size) {
            .one, .c => Span.spanned(info.child),
            else => @compileError("Span.spanned cannot be used on slices: " ++ @typeName(T)),
        },
        .@"struct" => {
            // thing.span or thing.span()
            if (@hasField(T, "span")) {
                return Span.spanned(@field(thing, "span"));
            }
            if (@hasDecl(T, "span")) {
                return @call(.auto, @field(T, "span"), .{});
            }
        },
        else => @compileError("Span.spanned cannot be used on type " ++ @typeName(T)),
    };
}

pub const Optional = struct {
    _raw: Span,

    pub const none = Optional{ ._raw = empty };

    pub inline fn init(span: ?Span) Span.Optional {
        return .{ ._raw = span orelse empty };
    }

    pub inline fn some(span: Span) Span.Optional {
        return .{ ._raw = span };
    }

    pub fn isSome(self: Span.Optional) bool {
        return @as(usize, @bitCast(self._raw)) != 0;
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
