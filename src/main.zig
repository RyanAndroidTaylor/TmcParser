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
                '+', '-', 195, '*' => try operatorScope(&allocator, context),
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
                    std.debug.print("Unsupported Char {d} at index: {d} \n", .{ c, context.index });

                    return LexError.UnsupportedType;
                },
            }
        }

        for (context.tokens.items) |token| {
            std.debug.print("Payload: {any}\n", .{token.type});
        }

        context.destroy(&allocator);
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
        const payload = try allocator.create(TypePayload);
        payload.* = TypePayload{ .number = context.copyFrom(start_index) };

        const token = try allocator.create(Token);
        token.* = Token{ .type = payload };

        try context.tokens.append(token);

        return;
    }

    if (context.peek() == ' ') {
        context.consumeChar();
    }

    return switch (context.peek()) {
        '+', '-', 195, '*' => {
            const payload = try allocator.create(TypePayload);
            payload.* = TypePayload{
                .number = context.copySlice(start_index, context.index - 1),
            };

            const token = try allocator.create(Token);
            token.* = Token{ .type = payload };

            try context.tokens.append(token);

            std.debug.print("From NumericScope ->\n", .{});

            try operatorScope(allocator, context);
        },
        '\'', '\"' => {
            try valueTypeScope(allocator, context, start_index);
        },
        '/' => {
            try fractionScope(allocator, context, start_index);
        },
        else => {
            std.debug.print("UnsupportedType \'{c}\' found while parsing numeric scope. At index {d}\n", .{ context.peek(), context.index });

            return LexError.UnsupportedType;
        },
    };
}

fn fractionScope(
    allocator: *std.mem.Allocator,
    context: *Context,
    start_index: u32,
) !void {
    const numerator = context.copyFrom(start_index);

    if (context.takeChar() != '/') {
        std.debug.print("Context is expected to be on '/' char when entering FractionScope", .{});

        return LexError.InvalidStructure;
    }

    const denominator_start = context.index;

    var next = context.takeChar();

    if (next < '0' or next > '9') {
        std.debug.print("Fractions require at least one denominator but found '{c}'\n", .{next});

        return LexError.InvalidStructure;
    }

    while (next >= '0' and next <= '9') {
        next = context.takeChar();
    }

    const denominator_string = context.copySlice(denominator_start, context.index - 1);

    const payload = try allocator.create(TypePayload);
    const fraction = try allocator.create(Fraction);

    fraction.* = Fraction{
        .numerator = numerator,
        .denominator = denominator_string,
    };

    payload.* = TypePayload{ .fraction = fraction };

    if (!context.isEof()) {
        const expectedSpace = context.takeChar();

        if (expectedSpace != ' ') {
            std.debug.print("Expected a space but found '{c}'\n", .{expectedSpace});

            return LexError.InvalidStructure;
        }
    }

    const token = try allocator.create(Token);
    token.* = Token{ .type = payload };

    try context.tokens.append(token);
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
            const payload = try allocator.create(TypePayload);
            payload.* = TypePayload{
                .feet = value,
            };

            token.* = Token{ .type = payload };
        },
        '\"' => {
            const payload = try allocator.create(TypePayload);
            payload.* = TypePayload{
                .inch = value,
            };

            token.* = Token{ .type = payload };
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
    // Divide symbol ÷ is two ascii characters and starts with 195.
    // So when we find 195 we know to take two characers
    const slice = if (context.peek() == 195) context.takeSlice(context.index + 2) else context.takeSlice(context.index + 1);

    const payload = try allocator.create(TypePayload);
    payload.* = TypePayload{
        .operator = slice,
    };

    const token = try allocator.create(Token);
    token.* = Token{ .type = payload };

    const char = context.takeChar();
    if (char != ' ') {
        std.debug.print("OperatorScope -> Found '{d}', index: {d}\n", .{ char, context.index - 1 });

        return LexError.InvalidStructure;
    }

    try context.tokens.append(token);
}

const TypePayload = union(enum) {
    number: []const u8,
    feet: []const u8,
    inch: []const u8,
    fraction: *Fraction,
    combine,
    operator: []const u8,

    fn destory(self: *TypePayload, allocator: *std.mem.Allocator) void {
        if (@as(TypePayload, self.*) == TypePayload.fraction) {
            allocator.destroy(self.fraction);
        }

        allocator.destroy(self);
    }
};

const Fraction = struct {
    numerator: []const u8,
    denominator: []const u8,
};

const Token = struct {
    type: *TypePayload,

    fn destory(self: *Token, allocator: *std.mem.Allocator) void {
        self.type.destory(allocator);
        allocator.destroy(self);
    }
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

    fn copySlice(self: *Context, from: u32, to: u32) []const u8 {
        return self.expression[from..to];
    }

    fn isEof(self: *Context) bool {
        return self.index == self.expression.len;
    }

    fn destroy(self: *Context, allocator: *std.mem.Allocator) void {
        for (self.tokens.items) |t| {
            t.destory(allocator);
        }

        self.tokens.deinit();
        allocator.destroy(self);
    }
};

const LexError = error{
    UnsupportedType,
    InvalidStructure,
};
