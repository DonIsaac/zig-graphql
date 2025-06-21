const std = @import("std");
const ascii = std.ascii;

// Name ::
// 
// - NameStart NameContinue\* [lookahead != NameContinue]
// 
// NameStart ::
// 
// - Letter
// - `_`
// 
// NameContinue ::
// 
// - Letter
// - Digit
// - `_`
pub fn isNameStart(c: u8) bool {
    return ascii.isAlphabetic(c) or c == '_';
}

pub fn isNameContinue(c: u8) bool {
    return ascii.isAlphanumeric(c) or c == '_';
}
