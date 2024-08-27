const std = @import("std");

// Tokens:
// Number, Operator, FractionSeparator, ValueType
//
// Passing in args to zig "zig build run -- some args (wrap in double quotes if there are spaces)
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
            else => {
                std.debug.print("Unsupported Char {c}\n", .{c});

                return LexError.UnsupportedType;
            },
        };

        std.debug.print("{any}\n", .{token});
    }
}

const Type = enum { number, operator, fraction_seperator, value_type };

const Token = struct { token_type: Type, value: u8 };

const LexError = error{UnsupportedType};
