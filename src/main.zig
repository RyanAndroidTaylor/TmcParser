const std = @import("std");

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

    for (expression.?) |c| {
        const token = switch (c) {
            // TODO Once a number is found we need to parse all digits until we reach a non-number character
            '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => Token{ .token_type = Type.number, .value = c },
            '\"', '\'' => Token{ .token_type = Type.value_type, .value = c },
            '+', '-', '÷', '*' => Token{ .token_type = Type.operator, .value = c },
            '/' => Token{ .token_type = Type.fraction_seperator, .value = c },
            ' ' => Token{ .token_type = Type.space, .value = c },
            else => {
                std.debug.print("Unsupported Char {c}\n", .{c});

                return LexError.UnsupportedType;
            },
        };

        std.debug.print("{any}\n", .{token});
    }
}

const Type = enum { number, operator, fraction_seperator, value_type, space };

const Token = struct { token_type: Type, value: u8 };

const LexError = error{UnsupportedType};
