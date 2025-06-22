const std = @import("std");
const LexerImpl = @import("LexerImpl.zig");
const ident = @import("ident.zig");
const util = @import("../util.zig");

const mem = std.mem;
const ascii = std.ascii;

const Token = LexerImpl.Token;

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
    BTK, LET, LET, LET, LET, L_e, LET, LET, LET, LET, LET, LET, LET, L_m, LET, LET, // 6
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
            '\n' => {
                return .comment;
            },
            else => lexer.bump(),
        }
    }
    return .comment;
}

/// Dollar (0x24) - $
fn DOL(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .dollar;
}

/// Percent (0x25) - %
fn PCT(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .percent;
}

/// Ampersand (0x26) - &
fn AMP(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .amp;
}

/// Single quote (0x27) - '
fn SQT(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .single_quote;
}

/// Left parenthesis (0x28) - (
fn LPA(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .l_paren;
}

/// Right parenthesis (0x29) - )
fn RPA(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .r_paren;
}

/// Asterisk (0x2A) - *
fn AST(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .asterisk;
}

/// Plus (0x2B) - +
fn PLS(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .plus;
}

/// Comma (0x2C) - ,
fn COM(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .comma;
}

/// Minus (0x2D) - -
fn MIN(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
    return .minus;
}

/// Period (0x2E) - .
fn DOT(lexer: *LexerImpl, _: u8) Token.Kind {
    lexer.bump();
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
    .{ "num", .@"enum" },
});

/// Lowercase m
const L_m: ByteHandler = keywordOrName('m', &[_]struct { []const u8, Token.Kind }{
    .{ "utation", .mutation },
});

/// Lowercase q
const L_q: ByteHandler = keywordOrName('q', &[_]struct { []const u8, Token.Kind }{
    .{ "uery", .query },
});

/// Lowercase s
const L_s: ByteHandler = keywordOrName('s', &[_]struct { []const u8, Token.Kind }{
    .{ "ubscription", .subscription },
    .{ "chema", .schema },
});

/// Lowercase t
const L_t: ByteHandler = keywordOrName('t', &[_]struct { []const u8, Token.Kind }{
    .{ "ype", .type },
});

/// Lowercase u
const L_u: ByteHandler = keywordOrName('u', &[_]struct { []const u8, Token.Kind }{
    .{ "nion", .@"union" },
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
    return .int_value;
}
