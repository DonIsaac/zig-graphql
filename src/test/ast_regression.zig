//! Snapshot regression tests for the parser.
//!
//! Each case in `ast_snapshots.zon` pairs a GraphQL `source` with the `ast` and
//! `errors` it parses into. Run with `UPDATE_SNAPSHOTS=1` to re-record them.
const std = @import("std");
const root = @import("../root.zig");
const lang = root.lang;
const Span = root.Span;
const Diagnostic = root.Diagnostic;

const Allocator = std.mem.Allocator;

const TestCase = struct {
    source: [:0]const u8,
    ast: ?lang.Ast.Document = null,
    errors: []const Diagnostic = &.{},

    fn toZon(case: TestCase, allocator: Allocator) (Allocator.Error || std.zon.Serializer.Error)![]u8 {
        var out: std.Io.Writer.Allocating = .init(allocator);
        errdefer out.deinit();
        var s: std.zon.Serializer = .{ .writer = &out.writer };
        try writeNode(&s, .{ .ast = case.ast, .errors = case.errors });
        return out.toOwnedSlice();
    }
};

const snapshot_path = "src/test/ast_snapshots.zon";

test "ast regression" {
    @setEvalBranchQuota(100_000);
    const gpa = std.testing.allocator;
    const io = std.testing.io;

    const snapshot_source = try std.Io.Dir.cwd().readFileAllocOptions(
        io,
        snapshot_path,
        gpa,
        .limited(16 * 1024 * 1024),
        .of(u8),
        0,
    );
    defer gpa.free(snapshot_source);

    var diag: std.zon.parse.Diagnostics = .{};
    defer diag.deinit(gpa);
    const snapshots: []TestCase = std.zon.parse.fromSliceAlloc(
        []TestCase,
        gpa,
        snapshot_source,
        &diag,
        .{},
    ) catch |e| switch (e) {
        error.OutOfMemory => |oom| return oom,
        else => |err| {
            std.debug.print("Failed to parse snapshot zon: {f}\n", .{diag});
            return err;
        },
    };
    defer std.zon.parse.free(gpa, snapshots);

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const alloc = arena.allocator();

    var actual = try std.ArrayList(TestCase).initCapacity(alloc, snapshots.len);
    for (snapshots) |snapshot| {
        var parser = lang.Parser.init(alloc, snapshot.source);
        actual.appendAssumeCapacity(.{
            .source = snapshot.source,
            .ast = try parser.parseDocument(),
            .errors = parser.errors(),
        });
    }

    const update = std.testing.environ.containsUnempty(std.testing.allocator, "UPDATE_SNAPSHOTS") catch false;
    var mismatches: usize = 0;
    var scratch = std.heap.ArenaAllocator.init(gpa);
    defer scratch.deinit();
    for (snapshots, actual.items, 0..) |expected_case, actual_case, i| {
        defer _ = scratch.reset(.retain_capacity);
        const allocator = scratch.allocator();
        const expected = try expected_case.toZon(allocator);
        const found = try actual_case.toZon(allocator);
        if (std.mem.eql(u8, expected, found)) continue;

        mismatches += 1;
        if (update) continue;
        std.debug.print(
            \\snapshot {d} does not match:
            \\--- source ---
            \\{s}
            \\--- expected ---
            \\{s}
            \\--- found ---
            \\{s}
            \\
        , .{ i, expected_case.source, expected, found });
    }

    if (!update) {
        if (mismatches == 0) return;
        std.debug.print(
            "{d}/{d} snapshots did not match. Re-run with UPDATE_SNAPSHOTS=1 to re-record.\n",
            .{ mismatches, snapshots.len },
        );
        return error.SnapshotMismatch;
    }

    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = snapshot_path,
        .data = try record(alloc, actual.items),
    });
    std.debug.print("re-recorded {s}\n", .{snapshot_path});
}

fn record(gpa: Allocator, cases: []const TestCase) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(gpa);
    errdefer out.deinit();

    var s: std.zon.Serializer = .{ .writer = &out.writer };
    var tuple = try s.beginTuple(wrapped);
    for (cases) |case| {
        var obj = try tuple.beginStructField(wrapped);

        try obj.fieldPrefix("source");
        // The prefix ends in `= `, but the multiline string starts on the next
        // line. Drop the space it left rather than trailing it off the line.
        std.debug.assert(out.writer.buffered()[out.writer.end - 1] == ' ');
        out.writer.end -= 1;
        try s.multilineString(case.source, .{});

        try obj.fieldPrefix("ast");
        try writeNode(&s, case.ast);
        try obj.fieldPrefix("errors");
        try writeNode(&s, case.errors);

        try obj.end();
    }
    try tuple.end();
    try out.writer.writeByte('\n');

    return out.toOwnedSlice();
}

/// Multiple lines, with a trailing comma to keep `zig fmt` from joining them.
const wrapped: std.zon.Serializer.ContainerOptions = .{ .whitespace_style = .{ .wrap = true } };

/// One line, no trailing comma.
const inlined: std.zon.Serializer.ContainerOptions = .{ .whitespace_style = .{ .wrap = false } };

/// Serialize an AST node. Unlike `std.zon.stringify`, this breaks out every
/// container wide enough to be worth reading a field at a time.
fn writeNode(s: *std.zon.Serializer, value: anytype) std.zon.Serializer.Error!void {
    @setEvalBranchQuota(100_000);
    switch (@typeInfo(@TypeOf(value))) {
        .optional => if (value) |payload| {
            try writeNode(s, payload);
        } else {
            try s.writer.writeAll("null");
        },

        .pointer => |pointer| switch (pointer.size) {
            .one => try writeNode(s, value.*),
            .slice => if (pointer.child == u8) {
                try s.value(value, .{});
            } else {
                var items = try s.beginTuple(wrapped);
                for (value) |item| {
                    try items.fieldPrefix();
                    try writeNode(s, item);
                }
                try items.end();
            },
            else => comptime unreachable,
        },

        .@"struct" => |info| {
            // Spans are on nearly every node; breaking out their two offsets
            // buries the contents.
            const options = if (@TypeOf(value) == Span or info.fields.len == 1) inlined else wrapped;
            var fields = try s.beginStruct(options);
            inline for (info.fields) |field| {
                try fields.fieldPrefix(field.name);
                try writeNode(s, @field(value, field.name));
            }
            try fields.end();
        },

        // A tagged union is a single-field struct, or a bare enum literal when
        // the active variant has no payload.
        .@"union" => switch (value) {
            inline else => |payload, tag| if (@TypeOf(payload) == void) {
                try s.ident(@tagName(tag));
            } else {
                var variant = try s.beginStruct(inlined);
                try variant.fieldPrefix(@tagName(tag));
                try writeNode(s, payload);
                try variant.end();
            },
        },

        else => try s.value(value, .{}),
    }
}
