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
// SCOPES: Take in a Context(index, expression, tokens)
//      Scopes need to make sure to update the index on the context once they
//      are done parsing and add the token they parsed to the tokens
//  NumberScope
//   - Parse entire number
//       - Find operator, return with this as value
//       - Find number, send to CombineScope with this as a parameter
//       - Find value_type, send to ValueTypeScope with this as a parameter
//       - Else error with message
//  ValueTypeScope
//   - Parse value_type
//       - Find operator, return with this as value
//       - Find number, send to CombineScope with this as a parameter
//       - Else error with message
//  CombineScope
//   - Parse
//       - Find operator, return with this as value
//       - Else error with message
//  FractionScope
//   - Parse
//       - Find operator, return with this as value
//       - Else error with message
//  OperatorScope
//   - Parse
//       - Find number, return with this as value
//       - Else error with message
//
// Tokens:
//  - number
//  - feet
//  - inch
//  - fraction
//  - combine (feet &| inch &| fraction)
//  - operator
//
// Abstract Syntax Tree (AST) (When building the tree keep in mind order of operation. Not all trees will build in the same order as the Final-Tokens list)
//           +
//         /  \
// raw_value   raw_value
//
pub fn main() !void {
    var arg_iterator = std.process.ArgIterator.init();

    // First arg will always be the name of the program
    _ = arg_iterator.skip();

    const expression = arg_iterator.next();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer if (gpa.deinit() == std.heap.Check.leak) {
        std.debug.print("Leaks Were Found!!!!!!!!!!!!!!!!!!!!!!!!", .{});
    };

    if (expression) |e| {
        std.debug.print("Parsing...\n", .{});

        var tokens = ArrayList(*Token).init(allocator);
        var context = try allocator.create(Context);

        context.* = Context{
            .index = 0,
            .expression = e,
            .tokens = &tokens,
        };

        while (context.index < e.len) {
            const c = e[context.index];

            switch (c) {
                // TODO Once a number is found we need to parse all digits until we reach a non-number character
                '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => try numericScope(&allocator, context),
                '+', '-', '÷', '*' => try operatorScope(&allocator, context),
                '\"', '\'' => {
                    std.debug.print("Found a value_type {c} not attached to a number\n", .{c});

                    return LexError.InvalidStructure;
                },
                '/' => {
                    std.debug.print("Error at index: {d}\n", .{context.index});
                    return LexError.InvalidStructure;
                },
                ' ' => {
                    std.debug.print("Error at index: {d}\n", .{context.index});
                    return LexError.InvalidStructure;
                },
                else => {
                    std.debug.print("Unsupported Char {c} at index: {d} \n", .{ c, context.index });

                    return LexError.UnsupportedType;
                },
            }
        }

        for (context.tokens.items) |t| {
            std.debug.print("{any}\n", .{t});

            allocator.destroy(t);
        }

        context.tokens.deinit();
        allocator.destroy(context);
    }
}

fn numericScope(
    allocator: *std.mem.Allocator,
    context: *Context,
) !void {
    const start_index = context.index;

    var next = context.peek();
    while (next >= '0' and next <= '9' and !context.isEof()) {
        context.index += 1;

        next = context.peek();
    }

    if (context.isEof()) {
        const token = try allocator.create(Token);

        token.* = Token{
            .token_type = Type.number,
            .value = context.copyFrom(start_index),
        };

        try context.tokens.append(token);
    } else {
        return switch (context.peek()) {
            ' ' => {
                const token = try allocator.create(Token);

                token.* = Token{
                    .token_type = Type.number,
                    .value = context.copyFrom(start_index),
                };

                context.consumeChar();

                try context.tokens.append(token);
            },
            '\'', '\"' => {
                try valueTypeScope(allocator, context, start_index);
            },
            else => {
                std.debug.print("UnsupportedType \'{c}\' found while parsing numeric scope. At index {d}\n", .{ context.peek(), context.index });

                return LexError.UnsupportedType;
            },
        };
    }
}

fn valueTypeScope(
    allocator: *std.mem.Allocator,
    context: *Context,
    start_index: u32,
) !void {
    const token = try allocator.create(Token);
    const value = context.copyFrom(start_index);
    const char = context.takeChar();

    switch (char) {
        '\'' => {
            token.* = Token{
                .token_type = Type.feet,
                .value = value,
            };
        },
        '\"' => {
            token.* = Token{
                .token_type = Type.inch,
                .value = value,
            };
        },
        else => {
            std.debug.print("UnsupportedType \'{c}\' found while parsing value_type scope. At index {d}\n", .{ context.peek(), context.index });

            return LexError.UnsupportedType;
        },
    }

    // Temp consume space until combine scope is setup
    context.consumeChar();

    try context.tokens.append(token);
}

fn operatorScope(
    allocator: *std.mem.Allocator,
    context: *Context,
) !void {
    const token = try allocator.create(Token);

    token.* = Token{
        .token_type = Type.operator,
        .value = context.takeSlice(context.index + 1),
    };

    if (context.takeChar() != ' ') {
        return LexError.InvalidStructure;
    }

    try context.tokens.append(token);
}

const Type = enum {
    number,
    feet,
    inch,
    fraction,
    combine,
    operator,
};

const Token = struct {
    token_type: Type,
    value: []const u8,
};

const Context = struct {
    index: u32,
    expression: [:0]const u8,
    tokens: *ArrayList(*Token),

    fn takeChar(self: *Context) u8 {
        const char = self.expression[self.index];

        self.index = self.index + 1;

        return char;
    }

    fn takeSlice(self: *Context, to: u32) []const u8 {
        const slice = self.expression[self.index..to];

        self.index = to;

        return slice;
    }

    fn consumeChar(self: *Context) void {
        self.index = self.index + 1;
    }

    fn peek(self: *Context) u8 {
        return self.expression[self.index];
    }

    fn copyFrom(self: *Context, from: u32) []const u8 {
        return self.expression[from..self.index];
    }

    fn isEof(self: *Context) bool {
        return self.index == self.expression.len;
    }
};

const LexError = error{
    UnsupportedType,
    InvalidStructure,
};
