const std = @import("std");
const LexerImpl = @import("LexerImpl.zig");
const Token = @import("Token.zig");
const ident = @import("ident.zig");
const util = @import("../../util.zig");

const ascii = std.ascii;

pub fn handleASCIIByte(lexer: *LexerImpl, byte: u8) Token.Kind {
    util.debugAssert(ascii.isASCII(byte));
    return @call(.auto, ASCII_TABLE[byte], .{ lexer, byte });
}

const ByteHandler = *const fn (lexer: *LexerImpl, byte: u8) Token.Kind;

// zig-fmt: off
pub const ASCII_TABLE: [128]ByteHandler = [_]ByteHandler{
    //  0    1    2    3    4    5    6    7    8    9    A    B    C    D    E    F
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, WSP, LF_, VT_, FF_, CR_, ERR, ERR, // 0
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // 1
    WSP, BNG, QUO, HSH, DOL, PCT, AMP, SQT, LPA, RPA, AST, PLS, COM, MIN, DOT, FSL, // 2
    DIG, DIG, DIG, DIG, DIG, DIG, DIG, DIG, DIG, DIG, COL, SEM, LTH, EQU, GTH, QUE, // 3
    AT_, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, // 4
    LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LBR, BSL, RBR, CRT, USC, // 5
    BTK, LET, LET, LET, LET, L_e, L_f, LET, LET, LET, LET, LET, LET, L_m, L_n, L_o, // 6
    LET, L_q, LET, L_s, L_t, LET, L_u, LET, LET, LET, LET, LCB, PIP, RCB, TLD, ERR, // 7
};
// zig-fmt: on

// ============================== BYTE HANDLERS ==============================

fn ERR(lexer: *LexerImpl, byte: u8) Token.Kind {
    lexer.fatalError("Unexpected byte: {c}", .{byte});
    return .undetermined;
}

// ============================== WHITESPACE & LINE TERMINATORS ==============================

/// Whitespace: Horizontal Tab (0x09) and Space (0x20)
fn WSP(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .whitespace;
}

/// Line Feed (0x0A) - Line Terminator
fn LF_(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .line_terminator;
}

/// Carriage Return (0x0D) - Line Terminator
/// Note: May be followed by Line Feed (0x0A)
fn CR_(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    if (lexer.curr() == '\n') lexer.bump();

    return .line_terminator;
}

/// Vertical Tabulation (0x0B) - Whitespace
fn VT_(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .whitespace;
}

/// Form Feed (0x0C) - Whitespace
fn FF_(lexer: *LexerImpl, _: u8) Token.Kind {
    // TODO: simd
    while (if (lexer.curr()) |c| ascii.isWhitespace(c) else false) {
        lexer.bump();
    }
    return .whitespace;
}

// ============================== PUNCTUATORS ==============================

/// Exclamation mark (0x21) - !
fn BNG(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .bang;
}

/// Double quote (0x22) - "
fn QUO(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .double_quote;
}

/// Hash (0x23) - # (Comment start)
fn HSH(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    while (lexer.curr()) |c| {
        switch (c) {
            // LineTerminator
            '\n', '\r' => {
                return .comment;
            },
            else => lexer.bump(),
        }
    }
    return .comment;
}

/// Dollar (0x24) - `$`
fn DOL(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .dollar;
}

/// Percent (0x25) - `%`
fn PCT(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .percent;
}

/// Ampersand (0x26) - `&`
fn AMP(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .amp;
}

/// Single quote (0x27) - `'`
fn SQT(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .single_quote;
}

/// Left parenthesis (0x28) - `(`
fn LPA(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .l_paren;
}

/// Right parenthesis (0x29) - `)`
fn RPA(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .r_paren;
}

/// Asterisk (0x2A) - `*`
fn AST(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .asterisk;
}

/// Plus (0x2B) - `+`
fn PLS(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .plus;
}

/// Comma (0x2C) - `,`
fn COM(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .comma;
}

/// Minus (0x2D) - `-`
fn MIN(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.expect('-');
    if (lexer.curr()) |c| {
        if (ascii.isDigit(c)) return DIG(lexer, c);
        if (c == '.') {
            lexer.bump();
            return lexFractionalPart(lexer);
        }
    }

    return .minus;
}

/// Period (0x2E) - `.`
fn DOT(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    // Check if this is the start of a fractional part
    if (lexer.curr()) |c| {
        if (c >= '0' and c <= '9') {
            // We have a fractional part without an integer part (e.g., .5)
            return lexFractionalPart(lexer);
        }
    }
    return .period;
}

/// Forward slash (0x2F) - /
fn FSL(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .forward_slash;
}

/// Colon (0x3A) - :
fn COL(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .colon;
}

/// Semicolon (0x3B) - ;
fn SEM(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .semicolon;
}

/// Less than (0x3C) - <
fn LTH(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .less_than;
}

/// Equal (0x3D) - =
fn EQU(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .equal;
}

/// Greater than (0x3E) - >
fn GTH(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .greater_than;
}

/// Question mark (0x3F) - ?
fn QUE(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .question_mark;
}

/// At (0x40) - @
fn AT_(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .at;
}

/// Left bracket (0x5B) - [
fn LBR(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .l_bracket;
}

/// Backslash (0x5C) - \
fn BSL(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .backslash;
}

/// Right bracket (0x5D) - ]
fn RBR(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .r_bracket;
}

/// Caret (0x5E) - ^
fn CRT(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .caret;
}

/// Underscore (0x5F) - _
fn USC(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .underscore;
}

/// Backtick (0x60) - `
fn BTK(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .backtick;
}

/// Left curly brace (0x7B) - {
fn LCB(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .l_curly;
}

/// Pipe (0x7C) - |
fn PIP(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .pipe;
}

/// Right curly brace (0x7D) - }
fn RCB(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .r_curly;
}

/// Tilde (0x7E) - ~
fn TLD(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .tilde;
}

// ============================== LETTERS & DIGITS ==============================

/// Lowercase e
const L_e: ByteHandler = keywordOrName('e', &[_]struct { []const u8, Token.Kind }{
    .{ "num", .kw_enum },
});

const L_f: ByteHandler = keywordOrName('f', &[_]struct { []const u8, Token.Kind }{
    .{ "alse", .kw_false },
    .{ "ragment", .kw_fragment },
});

/// Lowercase m
const L_m: ByteHandler = keywordOrName('m', &[_]struct { []const u8, Token.Kind }{
    .{ "utation", .kw_mutation },
});

const L_n: ByteHandler = keywordOrName('n', &[_]struct { []const u8, Token.Kind }{
    .{ "ull", .null_value },
});

// const L_o
fn L_o(lexer: *LexerImpl, c: u8) Token.Kind {
    if (lexer.peek() == 'n') {
        lexer.advanceBy(2);
        return .kw_on;
    }
    return LET(lexer, c);
}

/// Lowercase q
const L_q: ByteHandler = keywordOrName('q', &[_]struct { []const u8, Token.Kind }{
    .{ "uery", .kw_query },
});

/// Lowercase s
const L_s: ByteHandler = keywordOrName('s', &[_]struct { []const u8, Token.Kind }{
    .{ "ubscription", .kw_subscription },
    .{ "chema", .kw_schema },
});

/// Lowercase t
const L_t: ByteHandler = keywordOrName('t', &[_]struct { []const u8, Token.Kind }{
    .{ "ype", .kw_type },
    .{ "rue", .kw_true },
});

/// Lowercase u
const L_u: ByteHandler = keywordOrName('u', &[_]struct { []const u8, Token.Kind }{
    .{ "nion", .kw_union },
});

fn keywordOrName(comptime first: u8, comptime kws: anytype) ByteHandler {
    const gen = struct {
        pub fn byteHandler(lexer: *LexerImpl, _: u8) Token.Kind {
            lexer.expect(first);
            return ident.isKeywordWithoutFirstChar(lexer, kws) orelse lexNameRemaining(lexer);
        }
    };
    return gen.byteHandler;
}

/// Letters (0x41-0x5A, 0x61-0x7A) - A-Z, a-z
fn LET(lexer: *LexerImpl, c: u8) Token.Kind {
    util.debugAssert(ident.isNameStart(c));
    lexer.bump();
    return lexNameRemaining(lexer);
}

fn lexNameRemaining(lexer: *LexerImpl) Token.Kind {
    // NameStart should already be consumed
    util.debugAssert(lexer._cur != lexer.tok.span.start);
    while (lexer.curr()) |c| {
        if (!ident.isNameContinue(c)) {
            break;
        }
        lexer.bump();
    }
    return .name;
}

/// Digits (0x30-0x39) - 0-9
fn DIG(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    // Consume all consecutive digits
    while (lexer.curr()) |c| {
        switch (c) {
            '0'...'9' => {
                lexer.bump();
                continue;
            },
            // Check for fractional part
            '.' => {
                lexer.bump();
                return lexFractionalPart(lexer);
            },
            // Check for exponent part
            'e', 'E' => {
                lexer.bump();
                return lexExponentPart(lexer);
            },
            else => break,
        }
    }
    return .int_value;
}

fn lexFractionalPart(lexer: *LexerImpl) Token.Kind {
    // We've already consumed '.', now we need at least one digit
    if (lexer.curr()) |c| {
        if (c >= '0' and c <= '9') {
            // Consume all digits in fractional part
            while (lexer.curr()) |digit| {
                if (digit < '0' or digit > '9') {
                    break;
                }
                lexer.bump();
            }
            
            // Check for exponent part
            if (lexer.curr()) |exp| {
                if (exp == 'e' or exp == 'E') {
                    lexer.bump();
                    return lexExponentPart(lexer);
                }
            }
            
            return .float_value;
        }
    }
    
    // If we don't have digits after '.', this is invalid
    // For now, we'll return period and let the parser handle the error
    return .period;
}

fn lexExponentPart(lexer: *LexerImpl) Token.Kind {
    // We've already consumed 'e' or 'E', now check for optional sign
    if (lexer.curr()) |c| {
        if (c == '+' or c == '-') {
            lexer.bump();
        }
    }
    
    // We need at least one digit in the exponent
    if (lexer.curr()) |c| {
        if (c >= '0' and c <= '9') {
            // Consume all digits in exponent
            while (lexer.curr()) |digit| {
                if (digit < '0' or digit > '9') {
                    break;
                }
                lexer.bump();
            }
            return .float_value;
        }
    }
    
    // If we don't have digits in exponent, this is invalid
    // For now, we'll return the token type based on what we've seen so far
    return .float_value;
}
