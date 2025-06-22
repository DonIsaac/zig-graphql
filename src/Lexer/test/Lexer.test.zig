const std = @import("std");
const Lexer = @import("../../Lexer.zig");

const testing = std.testing;
const allocator = std.testing.allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

test "valid examples" {
    const valid = @embedFile("fixtures/valid.graphql");
    var files = std.mem.splitSequence(u8, valid, "====");
    _ = &files;

    while (files.next()) |f| {
        var arena = ArenaAllocator.init(allocator);
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
    const debug = false;
    const Kind = Lexer.Token.Kind;
    const TestCase = struct { []const u8, []const Kind };
    const test_cases = &[_]TestCase{
        .{ "", &[_]Kind{} },
        .{ "{}", &[_]Kind{ .l_curly, .r_curly } },
        .{ "#foo\n", &[_]Kind{.comment} },
        .{ "#foo", &[_]Kind{.comment} },
        .{
            "query MyQuery {}",
            &[_]Kind{ .query, .name, .l_curly, .r_curly },
        },
        .{
            "mutation Foo($bar: String!) { bar }",
            &[_]Kind{ .mutation, .name, .l_paren, .dollar, .name, .colon, .name, .bang, .r_paren, .l_curly, .name, .r_curly },
        },
        .{
            "enum Foo { A, B, C }",
            &[_]Kind{ .@"enum", .name, .l_curly, .name, .comma, .name, .comma, .name, .r_curly },
        },
    };

    for (test_cases) |tc| {
        const src, const expected = tc;
        var arena = ArenaAllocator.init(allocator);
        defer arena.deinit();
        var lexer = Lexer.init(arena.allocator(), src);

        var toks = std.ArrayList(Kind).init(arena.allocator());
        defer toks.deinit();

        while (try lexer.next()) |t| {
            if (debug) {
                const s = t.span;
                const tok_name = lexer.source[s.start..s.end];
                std.debug.print("{}: {s}\n", .{ t.kind, tok_name });
            }
            try toks.append(t.kind);
        }
        std.testing.expectEqualSlices(Kind, expected, toks.items) catch |e| {
            std.debug.print("\nSource:\n\n{s}\n\n", .{src});
            return e;
        };
    }
}
