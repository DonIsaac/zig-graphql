const std = @import("std");
const Lexer = @import("../Lexer.zig");

const ByteHandler = fn(lexer: *Lexer, byte: u8) void;
// zig-fmt: off
const ASCII_TABLE: [@bitSizeOf(u8)]ByteHandler = [_]ByteHandler{
//  0    1    2    3    4    5    6    7    8    9    A    B    C    D    E    F
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // 0
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // 1
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // 2
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // 3
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // 4
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // 5
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // 6
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // 7
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // 8
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // 9
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // A
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // B
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // C
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // D
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // E
    ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, ERR, // F
};
// zig-fmt: on

fn ERR(lexer: *Lexer, byte: u8) void {
    lexer.fatalError("Unexpected byte: {c}", .{byte});
}

// whitespace


/// Whitespace
/// - 0x09 horizontal tab
/// - 0x20 space 
fn WSP(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .whitespace;
}

// 9 011	09	00001001	HT	&#09;	 	Horizontal Tab
// 10 012	0A	00001010	LF	&#10;	 	Line Feed
// 11 013	0B	00001011	VT	&#11;	 	Vertical Tabulation
// 12 014	0C	00001100	FF	&#12;	 	Form Feed
// 13 015	0D	00001101	CR	&#13;	 	Carriage Return

// LineTerminator ::
// 
// - "New Line (U+000A)"
// - "Carriage Return (U+000D)" [lookahead != "New Line (U+000A)"]
// - "Carriage Return (U+000D)" "New Line (U+000A)"
/// 0x0A line feed
fn LF_(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .line_terminator;
}

fn CR_(lexer: *Lexer, _: u8) void {

// 0x0B vertical tabulation
fn VT_(lexer: *Lexer, _: u8) void {
    lexer.bump();
    lexer.tok.kind = .whitespace;
}


// 0x0D carriage return
fn CR_(lexer: *Lexer, byte: u8) void {
    lexer.bump();
    lexer.tok.kind = .whitespace;
}
