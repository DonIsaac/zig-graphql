const Token = @This();

span: Span,
kind: Kind,

pub const empty = Token{ .span = .empty, .kind = .undetermined };

pub const Kind = enum {
    undetermined,

    // Keywords
    query,
    mutation,
    subscription,
    fragment,
    @"type",
    implements,
    interface,
    @"union",
    @"enum",
    scalar,
    input,
    directive,
    schema,
    extend,

    // Punctuators
    bang,
    dollar,
    percent,
    amp,
    single_quote,
    l_paren, // (
    r_paren, // )
    l_bracket, // [
    r_bracket, // ]
    l_curly, // {
    r_curly, // }
    colon, // :
    equal, // =
    at, // @
    pipe, // |

    // whitespace, etc
    eof,
    whitespace,
    line_terminator,
    comment,
    block_comment,
};

const Span = @import("../Span.zig");
