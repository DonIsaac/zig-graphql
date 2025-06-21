const std = @import("std");
const Lexer = @import("../Lexer.zig");
const ident = @import("ident.zig");

const ByteHandler = *const fn(lexer: *Lexer, byte: u8) void;

// zig-fmt: off
pub const ASCII_TABLE: [128]ByteHandler = [_]ByteHandler{
//  0    1    2    3    4    5    6    7    8    9    A    B    C    D    E    F
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, WSP, LF_, VT_, FF_, CR_, ERR, ERR, // 0
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // 1
    WSP, BNG, QUO, HSH, DOL, PCT, AMP, SQT, LPA, RPA, AST, PLS, COM, MIN, DOT, FSL, // 2
    DIG, DIG, DIG, DIG, DIG, DIG, DIG, DIG, DIG, DIG, COL, SEM, LTH, EQU, GTH, QUE, // 3
    AT_, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, // 4
    LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LBR, BSL, RBR, CRT, USC, // 5
    BTK, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, // 6
    LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LET, LCB, PIP, RCB, TLD, ERR, // 7
    // ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // 8
    // ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // 9
    // ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // A
    // ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // B
    // ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // C
    // ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // D
    // ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // E
    // ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // F
};
// zig-fmt: on

// ============================== BYTE HANDLERS ==============================

fn ERR(lexer: *Lexer, byte: u8) void {
    lexer.fatalError("Unexpected byte: {c}", .{byte});
}

// ============================== WHITESPACE & LINE TERMINATORS ==============================

/// Whitespace: Horizontal Tab (0x09) and Space (0x20)
fn WSP(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .whitespace;
}

/// Line Feed (0x0A) - Line Terminator
fn LF_(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .line_terminator;
}

/// Carriage Return (0x0D) - Line Terminator
/// Note: May be followed by Line Feed (0x0A)
fn CR_(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .line_terminator;
}

/// Vertical Tabulation (0x0B) - Whitespace
fn VT_(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .whitespace;
}

/// Form Feed (0x0C) - Whitespace
fn FF_(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .whitespace;
}

// ============================== PUNCTUATORS ==============================

/// Exclamation mark (0x21) - !
fn BNG(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .bang;
}

/// Double quote (0x22) - "
fn QUO(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .double_quote;
}

/// Hash (0x23) - # (Comment start)
fn HSH(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .hash;
}

/// Dollar (0x24) - $
fn DOL(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .dollar;
}

/// Percent (0x25) - %
fn PCT(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .percent;
}

/// Ampersand (0x26) - &
fn AMP(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .amp;
}

/// Single quote (0x27) - '
fn SQT(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .single_quote;
}

/// Left parenthesis (0x28) - (
fn LPA(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .l_paren;
}

/// Right parenthesis (0x29) - )
fn RPA(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .r_paren;
}

/// Asterisk (0x2A) - *
fn AST(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .asterisk;
}

/// Plus (0x2B) - +
fn PLS(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .plus;
}

/// Comma (0x2C) - ,
fn COM(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .comma;
}

/// Minus (0x2D) - -
fn MIN(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .minus;
}

/// Period (0x2E) - .
fn DOT(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .period;
}

/// Forward slash (0x2F) - /
fn FSL(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .forward_slash;
}

/// Colon (0x3A) - :
fn COL(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .colon;
}

/// Semicolon (0x3B) - ;
fn SEM(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .semicolon;
}

/// Less than (0x3C) - <
fn LTH(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .less_than;
}

/// Equal (0x3D) - =
fn EQU(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .equal;
}

/// Greater than (0x3E) - >
fn GTH(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .greater_than;
}

/// Question mark (0x3F) - ?
fn QUE(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .question_mark;
}

/// At (0x40) - @
fn AT_(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .at;
}

/// Left bracket (0x5B) - [
fn LBR(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .l_bracket;
}

/// Backslash (0x5C) - \
fn BSL(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .backslash;
}

/// Right bracket (0x5D) - ]
fn RBR(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .r_bracket;
}

/// Caret (0x5E) - ^
fn CRT(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .caret;
}

/// Underscore (0x5F) - _
fn USC(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .underscore;
}

/// Backtick (0x60) - `
fn BTK(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .backtick;
}

/// Left curly brace (0x7B) - {
fn LCB(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .l_curly;
}

/// Pipe (0x7C) - |
fn PIP(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .pipe;
}

/// Right curly brace (0x7D) - }
fn RCB(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .r_curly;
}

/// Tilde (0x7E) - ~
fn TLD(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .tilde;
}

// ============================== LETTERS & DIGITS ==============================

/// Letters (0x41-0x5A, 0x61-0x7A) - A-Z, a-z
fn LET(lexer: *Lexer, c: u8) void {
    util.debugAssert(ident.isNameStart(c));
    lexer.bump();
    var next = lexer.peek();
    while (next != null and ident.isNameContinue(next.?)) {
        lexer.bump();
        next = lexer.peek();
    }
    lexer.tok.kind = .name;
}

/// Digits (0x30-0x39) - 0-9
fn DIG(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .int_value;
}


const util = @import("../util.zig");
