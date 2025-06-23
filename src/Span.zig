const Span = @This();

/// Start position from the beginning of the source text
start: u32,
/// End position
end: u32,

pub const empty = Span{ .start = 0, .end = 0 };

/// Create a Span starting at some position that is `size` bytes long
pub inline fn sized(start: u32, size: u32) Span {
    return .{ .start = start, .end = start + size };
}

pub fn eql(self: Span, other: Span) bool {
    return self.start == other.start and self.end == other.end;
}

pub inline fn len(self: Span) u32 {
    std.debug.assert(self.start <= self.end);
    return self.end - self.start;
}

pub inline fn offset(self: Span, comptime kind: enum { Start, End }) Span.Offset {
    return Span.Offset.init(if (comptime kind == .Start) self.start else self.end);
}

pub fn slice(self: Span, text: []const u8) []const u8 {
    std.debug.assert(self.start <= self.end);
    return text[self.start..self.end];
}

pub fn spanned(thing: anytype) Span {
    const T = @TypeOf(thing);
    return Span.spannedT(T, thing);
}

pub fn spannedT(comptime T: type, thing: T) Span {
    switch (T) {
        Span => return thing,
        Span.Optional => return Span.Optional.unwrap(thing),
        // *const Span, *Span, => return *thing,
        else => {},
    }

    const info = @typeInfo(T);
    return switch (info) {
        .pointer => |ptr| {
            if (comptime ptr.size != .one) {
                @compileError("slices, many-sized pointers, and c pointers cannot be spanned");
            }
            // TODO: looks like a compiler bug
            // > src/Span.zig:59:40: error: unable to resolve comptime value
            // >                 *Span, *const Span => *thing,
            // >                                        ^~~~~
            // > src/Span.zig:59:40: note: types must be comptime-known
            // break :p switch (T) {
            //     *Span, *const Span => *thing,
            //     else => @compileError(std.fmt.comptimePrint("Span.spanned cannot be used on pointer to type '{s}'", .{@typeName(T)})),
            // };
            @compileError(std.fmt.comptimePrint("Span.spanned cannot be used on pointer to type '{s}'", .{@typeName(T)}));
        },
        .@"struct" => {
            // thing.span or thing.span()
            if (@hasField(T, "span")) {
                return Span.spannedT(@FieldType(T, "span"), @field(thing, "span"));
            }
            if (@hasDecl(T, "span")) {
                return @call(.auto, @field(T, "span"), .{thing});
            }
        },
        .@"union" => switch (thing) {
            inline else => |value| Span.spanned(value),
        },
        else => @compileError(std.fmt.comptimePrint("Span.spanned cannot be used on type '{any}'", .{@typeName(T)})),
        // else => @compileError("Type cannot be spanned"),
    };
}

pub const Offset = enum(u32) {
    _,
    pub inline fn init(value: u32) Offset {
        return @enumFromInt(value);
    }
    pub inline fn valueOf(self: Offset) u32 {
        return @intFromEnum(self);
    }

    pub inline fn spanSized(self: Offset, size: u32) Span {
        return Span.sized(self.valueOf(), size);
    }

    /// Create a `Span` to cover a comptime-known keyword starting at this
    /// `Offset`.
    pub inline fn keywordSpan(self: Offset, comptime keyword: []const u8) Span {
        return Span.sized(self.valueOf(), @intCast(keyword.len));
    }
};

pub const Optional = struct {
    _raw: Span,

    pub const none = Optional{ ._raw = empty };

    pub inline fn init(span: ?Span) Span.Optional {
        return .{ ._raw = if (span) |s| Optional.some(s) else .empty };
    }

    pub inline fn some(span: Span) Span.Optional {
        std.debug.assert(!span.eql(.empty));
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

const t = std.testing;
test "Span.spanned" {
    const s = Span.empty;
    try t.expectEqual(Span.empty, Span.spanned(s)); // base case

    // struct/etc with span property
    const HasSpanProp = struct { span: Span };
    try t.expectEqual(s, Span.spanned(HasSpanProp{ .span = s }));

    // span() method
    const HasSpanMethod = struct {
        pub fn span(_: @This()) Span {
            return Span.empty;
        }
    };
    try t.expectEqual(s, Span.spanned(HasSpanMethod{}));

    // spanned() recurses down variants of tagged unions
    const UnionWithSpannedVariants = union(enum) {
        first: Span,
        second: HasSpanProp,
        third: HasSpanMethod,
    };
    try t.expectEqual(s, Span.spanned(UnionWithSpannedVariants{ .first = s }));
    try t.expectEqual(s, Span.spanned(UnionWithSpannedVariants{ .second = .{ .span = s } }));
    try t.expectEqual(s, Span.spanned(UnionWithSpannedVariants{ .third = .{} }));
}
