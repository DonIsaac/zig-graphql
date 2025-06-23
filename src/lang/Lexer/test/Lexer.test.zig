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

        try testing.expectEqual(lexer._impl.errors.items.len, 0);
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
            &[_]Kind{ .kw_query, .name, .l_curly, .r_curly },
        },
        .{
            "mutation Foo($bar: String!) { bar }",
            &[_]Kind{ .kw_mutation, .name, .l_paren, .dollar, .name, .colon, .name, .bang, .r_paren, .l_curly, .name, .r_curly },
        },
        .{
            "enum Fruit { Apple, Banana, Cherry }",
            &[_]Kind{ .kw_enum, .name, .l_curly, .name, .comma, .name, .comma, .name, .r_curly },
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
                const tok_name = lexer._impl.source[s.start..s.end];
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

// IntValue :: IntegerPart [lookahead != {Digit, `.`, NameStart}]
//
// IntegerPart ::
//
// - NegativeSign? 0
// - NegativeSign? NonZeroDigit Digit\*
//
// NegativeSign :: -
//
// NonZeroDigit :: Digit but not `0`
test "integer lexing" {
    const debug = false;
    const Kind = Lexer.Token.Kind;
    const TestCase = struct { []const u8, []const Kind };
    const test_cases = &[_]TestCase{
        .{ "123", &[_]Kind{.int_value} },
        .{ "0", &[_]Kind{.int_value} },
        .{ "-0", &[_]Kind{.int_value} },
        .{ "+0", &[_]Kind{ .plus, .int_value } },
        .{ "0-", &[_]Kind{ .int_value, .minus } },
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
                const tok_name = lexer._impl.source[s.start..s.end];
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

// FloatValue :: IntegerPart FractionalPart ExponentPart [lookahead != {Digit, `.`, NameStart}]
//              | IntegerPart FractionalPart [lookahead != {Digit, `.`, NameStart}]
//              | IntegerPart ExponentPart [lookahead != {Digit, `.`, NameStart}]
test "float lexing" {
    const debug = false;
    const Kind = Lexer.Token.Kind;
    const TestCase = struct { []const u8, []const Kind };
    const test_cases = &[_]TestCase{
        // IntegerPart FractionalPart
        .{ "123.456", &[_]Kind{.float_value} },
        .{ "0.5", &[_]Kind{.float_value} },
        .{ "-0.5", &[_]Kind{.float_value} },
        .{ "+0.5", &[_]Kind{ .plus, .float_value } },

        // IntegerPart ExponentPart
        .{ "123e10", &[_]Kind{.float_value} },
        .{ "123E10", &[_]Kind{.float_value} },
        .{ "123e+10", &[_]Kind{.float_value} },
        .{ "123e-10", &[_]Kind{.float_value} },
        .{ "-123e10", &[_]Kind{.float_value} },
        .{ "+123e10", &[_]Kind{ .plus, .float_value } },

        // IntegerPart FractionalPart ExponentPart
        .{ "123.456e10", &[_]Kind{.float_value} },
        .{ "123.456E+10", &[_]Kind{.float_value} },
        .{ "123.456e-10", &[_]Kind{.float_value} },
        .{ "-123.456e10", &[_]Kind{.float_value} },

        // FractionalPart (no IntegerPart)
        .{ ".5", &[_]Kind{.float_value} },
        .{ "-.5", &[_]Kind{.float_value} },
        .{ "+.5", &[_]Kind{ .plus, .float_value } },

        // FractionalPart ExponentPart
        .{ ".5e10", &[_]Kind{.float_value} },
        .{ ".5E+10", &[_]Kind{.float_value} },
        .{ "-.5e-10", &[_]Kind{.float_value} },
    };

    for (test_cases) |tc| {
        const src, const expected = tc;
        var arena = ArenaAllocator.init(allocator);
        defer arena.deinit();
        var lexer = Lexer.init(arena.allocator(), src);

        var kinds = std.ArrayList(Kind).init(arena.allocator());
        defer kinds.deinit();

        var toks = std.ArrayList(Lexer.Token).init(arena.allocator());
        defer toks.deinit();

        while (try lexer.next()) |t| {
            if (debug) {
                const s = t.span;
                const tok_name = lexer._impl.source[s.start..s.end];
                std.debug.print("{}: {s}\n", .{ t.kind, tok_name });
            }
            try kinds.append(t.kind);
            try toks.append(t);
        }
        std.testing.expectEqualSlices(Kind, expected, kinds.items) catch |e| {
            std.debug.print("\nSource:\n\n{s}\n\n", .{src});
            return e;
        };

        if (toks.items.len == 1) {
            const float = toks.items[0];
            try std.testing.expectEqual(.float_value, float.kind);
            const tok_slice = float.span.slice(src);
            try std.testing.expectEqualStrings(src, tok_slice);
        }
    }
}

test "string lexing" {
    const debug = false;
    const Kind = Lexer.Token.Kind;
    const TestCase = struct { []const u8, []const Kind };
    const test_cases = &[_]TestCase{
        .{
            \\"foo"
            ,
            &[_]Kind{.string_value},
        },
        .{
            \\"foo\nbar"
            ,
            &[_]Kind{.string_value},
        },
        .{
            \\"foo\"bar"
            ,
            &[_]Kind{.string_value},
        },
        .{
            \\"""
            \\"foo"
            \\"""
            ,
            &[_]Kind{.block_string_value},
        },
    };

    for (test_cases) |tc| {
        const src, const expected = tc;
        var arena = ArenaAllocator.init(allocator);
        defer arena.deinit();
        var lexer = Lexer.init(arena.allocator(), src);

        var kinds = std.ArrayList(Kind).init(arena.allocator());
        defer kinds.deinit();

        // var toks = std.ArrayList(Lexer.Token).init(arena.allocator());
        // defer toks.deinit();

        while (try lexer.next()) |t| {
            if (debug) {
                const s = t.span;
                const tok_name = lexer._impl.source[s.start..s.end];
                std.debug.print("{}: {s}\n", .{ t.kind, tok_name });
            }
            try kinds.append(t.kind);
        }
        std.testing.expectEqualSlices(Kind, expected, kinds.items) catch |e| {
            std.debug.print("\nSource:\n\n{s}\n\n", .{src});
            return e;
        };
    }
}
