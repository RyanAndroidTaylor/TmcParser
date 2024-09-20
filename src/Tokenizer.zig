const std = @import("std");
const tokens = @import("tokens.zig");

const Token = tokens.Token;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub fn tokenize(allocator: Allocator, expression: [:0]const u8) ArrayList(Token) {
    const arrayList = ArrayList(Token).init(allocator);

    std.debug.print("Tokenizing: {s}\n", .{expression});

    return arrayList;
}
