const std = @import("std");
const Lexer = @import("../../Lexer.zig");

const testing = std.testing;
const allocator = std.testing.allocator;

test "valid examples" {
    const valid = @embedFile("fixtures/valid.graphql");
    var files = std.mem.splitSequence(u8, valid, "====");
    _ = &files;

    while (files.next()) |f| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const src = std.mem.trim(u8, f, &std.ascii.whitespace);
        var lexer = Lexer.init(arena.allocator(), src);

        while (lexer.next() catch |e| {
            std.debug.print("Lexing failed: {}\n\nSource:\n\n{s}\n\n", .{ e, src });
            return e;
        }) |t| {
            _ = t;
        }

        try testing.expectEqual(lexer.errors.items.len, 0);
    }
}

test "spot check - valid" {
    const Kind = Lexer.Token.Kind;
    const TestCase = struct { []const u8, []const Kind };
    const test_cases = &[_]TestCase{
        .{
            "{}",
            &[_]Kind{ .l_curly, .r_curly },
        },
        .{
            "query MyQuery {}",
            &[_]Kind{ .query, .name, .l_curly, .r_curly },
        },
    };

    for (test_cases) |tc| {
        const src, const expected = tc;
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var lexer = Lexer.init(arena.allocator(), src);

        var toks = std.ArrayList(Kind).init(arena.allocator());
        defer toks.deinit();

        while (try lexer.next()) |t| {
            try toks.append(t.kind);
        }
        std.testing.expectEqualSlices(Kind, expected, toks.items) catch |e| {
            std.debug.print("\nSource:\n\n{s}\n\n", .{src});
            return e;
        };
    }
}
