const std = @import("std");
const tokens = @import("tokens.zig");

const Token = tokens.Token;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub fn tokenize(allocator: Allocator, expression: [:0]const u8) ArrayList(Token) {
    var arrayList = ArrayList(Token).init(allocator);

    std.debug.print("Tokenizing: {s}\n", .{expression});

    arrayList.append(Token{
        .number = tokens.NumberToken().inint(allocator, 1.1, 0, 1),
    }) catch unreachable;

    return arrayList;
}
