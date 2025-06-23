const Token = @This();

span: Span,
kind: Kind,

pub const empty = Token{ .span = .empty, .kind = .undetermined };

pub const Kind = enum {
    undetermined,

    // Keywords
    kw_directive,
    kw_enum,
    kw_extend,
    kw_false,
    kw_fragment,
    kw_implements,
    kw_input,
    kw_interface,
    kw_mutation,
    kw_on,
    kw_query,
    kw_scalar,
    kw_schema,
    kw_subscription,
    kw_true,
    kw_type,
    kw_union,

    // Punctuators
    bang, // !
    dollar, // $
    l_paren, // (
    r_paren, // )
    /// `[`
    l_bracket,
    /// `]`
    r_bracket,
    l_curly, // {
    r_curly, // }
    percent, // %
    amp, // &
    spread, // ...
    single_quote, // '
    asterisk, // *
    plus, // +
    comma, // ,
    minus, // -
    period, // .
    forward_slash, // /
    colon, // :
    semicolon, // ;
    less_than, // <
    equal, // =
    greater_than, // >
    question_mark, // ?
    at, // @
    caret, // ^
    underscore, // _
    backtick, // `
    backslash, // \
    pipe, // |
    tilde, // ~

    // String and comment tokens
    double_quote, // "
    hash, // #

    // Name and value tokens
    name,
    int_value,
    float_value,
    string_value,
    block_string_value,
    boolean_value,
    null_value,

    // whitespace, etc
    eof,
    whitespace,
    line_terminator,
    comment,
    block_comment,

    pub inline fn isIgnored(self: Kind) bool {
        return switch (self) {
            .whitespace, .line_terminator, .comment, .block_comment, .comma => true,
            else => false,
        };
    }
};

const Span = @import("../Span.zig");
