const std = @import("std");
const ArrayList = std.ArrayList;

// Tokens:
// Number, Operator, FractionSeparator, ValueType
//
// Passing in args to zig, zig build run -- some args (wrap in double quotes if there are spaces)
//
// Raw Text
// 1 1/2" + 2' 12 13/16"
//
// Char-Tokens
// num, space, num, fraction_seperator, num, value_type, space, operator, space, num, value_type, space, num, num, space, num, num, fraction_seperator, num, num, value_type
//
// Refined-Tokens
// num, fraction, operator, feet, number, fraction
//
// Final-Tokens
// calc-node    operator       calc-node
//
// Abstract Syntax Tree (AST) (When building the tree keep in mind order of operation. Not all trees will build in the same order as the Final-Tokens list)
//           +
//         /  \
// raw_value   raw_value
//
//
pub fn main() !void {
    var arg_iterator = std.process.ArgIterator.init();

    // First arg will always be the name of the program
    _ = arg_iterator.skip();

    const expression = arg_iterator.next();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    var tokens = ArrayList(*Token).init(allocator);

    if (expression) |e| {
        std.debug.print("Parsing...\n", .{});

        var index: u32 = 0;

        while (index < e.len) {
            const c = e[index];

            switch (c) {
                // TODO Once a number is found we need to parse all digits until we reach a non-number character
                '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => {
                    index = try numeric(&allocator, e, &tokens, index);
                },
                '\"', '\'' => {
                    const token = try allocator.create(Token);

                    token.* = Token{
                        .token_type = Type.value_type,
                        .value = e[index .. index + 1],
                    };

                    try tokens.append(token);

                    index = index + 1;
                },
                '+', '-', '÷', '*' => {
                    const token = try allocator.create(Token);

                    token.* = Token{
                        .token_type = Type.operator,
                        .value = e[index .. index + 1],
                    };

                    try tokens.append(token);

                    index = index + 1;
                },
                '/' => {
                    const token = try allocator.create(Token);

                    token.* = Token{
                        .token_type = Type.fraction_seperator,
                        .value = e[index .. index + 1],
                    };

                    try tokens.append(token);

                    index = index + 1;
                },
                ' ' => {
                    const token = try allocator.create(Token);

                    token.* = Token{
                        .token_type = Type.space,
                        .value = e[index .. index + 1],
                    };

                    try tokens.append(token);

                    index = index + 1;
                },
                else => {
                    std.debug.print("Unsupported Char {c}\n", .{c});

                    return LexError.UnsupportedType;
                },
            }

            //std.debug.print("{any}\n", .{token});
        }
    }

    for (tokens.items) |t| {
        std.debug.print("{any}\n", .{t});
    }
}

fn numeric(
    allocator: *std.mem.Allocator,
    expression: [:0]const u8,
    tokens: *ArrayList(*Token),
    index: u32,
) !u32 {
    var finalIndex = index;
    const token = try allocator.create(Token);

    var next = expression[finalIndex];
    while (next >= '0' and next <= '9') {
        finalIndex += 1;

        next = expression[finalIndex];
    }

    token.* = Token{
        .token_type = Type.number,
        .value = expression[index..finalIndex],
    };

    try tokens.append(token);

    return finalIndex;
}

const Type = enum { number, operator, fraction_seperator, value_type, space };

const Token = struct {
    token_type: Type,
    value: []const u8,
};

const LexError = error{UnsupportedType};
