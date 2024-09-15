const std = @import("std");
const ArrayList = std.ArrayList;
const Context = @import("context.zig").Context;

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

        context.* = Context{ .index = 0, .expression = e };

        while (context.index < e.len) {
            const c = e[context.index];

            const payload = switch (c) {
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
            };

            const token = try allocator.create(Token);
            token.* = Token{ .payload = payload };

            try tokens.append(token);
        }

        for (tokens.items) |token| {
            std.debug.print("Payload: {any}\n", .{token.payload});
        }

        context.destroy(&allocator);
        for (tokens.items) |t| {
            t.destory(&allocator);
        }
        tokens.deinit();
    }
}

fn numericScope(
    allocator: *std.mem.Allocator,
    context: *Context,
) !*TypePayload {
    const start_index = context.index;

    var next = context.peek();
    while (next >= '0' and next <= '9' and !context.isEof()) {
        context.index += 1;

        next = context.peek();
    }

    if (context.isEof()) {
        const payload = try allocator.create(TypePayload);
        payload.* = TypePayload{ .number = context.copyFromToCurrent(start_index) };

        return payload;
    }

    const value = context.copyFromToCurrent(start_index);

    if (context.peek() == ' ') {
        context.consumeChar();
    }

    return switch (context.peek()) {
        '+', '-', 195, '*' => {
            const payload = try allocator.create(TypePayload);
            payload.* = TypePayload{ .number = value };

            return payload;
        },
        '\'', '\"' => {
            return try valueTypeScope(allocator, context, start_index);
        },
        '/' => {
            return try fractionScope(allocator, context, start_index);
        },
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => {
            // We can only get her if we just parsed and inch and it has a fraction.
            // If the value is a feet it will have a ' attached to it
            // 2 1/2"  2' 1/2"   2' 1 1/2"

            return try combineScope(allocator, context, value, null);
        },
        else => {
            std.debug.print("UnsupportedType \'{c}\' found while parsing numeric scope. At index {d}\n", .{ context.peek(), context.index });

            return LexError.UnsupportedType;
        },
    };
}

fn combineScope(
    allocator: *std.mem.Allocator,
    context: *Context,
    inch: ?[]const u8,
    feet: ?[]const u8,
) !*TypePayload {
    // Feet? -> Inch? -> Fraction?
    // All optional but at least one required
    // The CombineScope should only be entered with a Feet or Inch value
    if (inch != null and feet != null) {
        std.debug.print("Entered CombineScope with non null feet and inch. CombineScope should be entered with either a feet or inch value but not both", .{});

        return LexError.InvalidStructure;
    } else if (inch != null) {
        const start_index = context.index;

        // Since we entered CombineScope wiht an inch we are expecting the next scope to be fraction
        // If not we need to return and error because the expression is malformed
        var next = context.peek();
        while (next != '/') {
            if (context.isEof()) {
                std.debug.print("Found end of file while lookig for '/'", .{});

                return LexError.InvalidStructure;
            }

            context.consumeChar();

            next = context.peek();
        }
        const fraction = try fractionScope(allocator, context, start_index);

        const combine = try allocator.create(Combine);
        combine.* = Combine{
            .feet = null,
            .inch = inch,
            .fraction = fraction,
        };

        const payload = try allocator.create(TypePayload);
        payload.* = TypePayload{ .combine = combine };

        return payload;
    } else if (feet != null) {
        // Next scope can be inch or fraction
        // Looking for / or "
        const start_index = context.index;

        var next = context.peek();
        while (next != '/' and next != '"' and next != ' ' and !context.isEof()) {
            context.consumeChar();
            next = context.peek();
        }

        if (next == '/') {
            const fraction = try fractionScope(allocator, context, start_index);
            const combine = try allocator.create(Combine);
            combine.* = Combine{
                .feet = feet,
                .inch = null,
                .fraction = fraction,
            };

            const payload = try allocator.create(TypePayload);
            payload.* = TypePayload{ .combine = combine };

            return payload;
        } else if (next == '"') {
            const combine = try allocator.create(Combine);
            combine.* = Combine{
                .feet = feet,
                .inch = context.copyFromToCurrent(start_index),
                .fraction = null,
            };

            const payload = try allocator.create(TypePayload);
            payload.* = TypePayload{ .combine = combine };

            return payload;
        } else if (next == ' ') {
            const parsed_inch = context.copyFromToCurrent(start_index);

            // Consome current space
            context.consumeChar();

            const fraction_start_index = context.index;

            var fraction_next = context.takeChar();
            while (context.peek() != '/') {
                if (context.peek() < '0' or context.peek() > '9') {
                    std.debug.print("Found an unexpected token while parsing CombineScope. Token: {c}, Index: {d}\n", .{ context.peek(), context.index });

                    return LexError.InvalidStructure;
                }

                if (context.isEof()) {
                    std.debug.print("Expected a FractionScope but was unable to find '/' here -> {any}\n", .{context.copyFromToEof(fraction_start_index)});

                    return LexError.InvalidStructure;
                }

                fraction_next = context.takeChar();
            }

            const fraction = try fractionScope(allocator, context, fraction_start_index);

            const combine = try allocator.create(Combine);
            combine.* = Combine{
                .feet = feet,
                .inch = parsed_inch,
                .fraction = fraction,
            };

            const payload = try allocator.create(TypePayload);
            payload.* = TypePayload{ .combine = combine };

            return payload;
        } else {
            std.debug.print("Was unable to find inch or fraction after feet. Next: {c}, Index: {d}\n", .{ next, context.index });

            return LexError.InvalidStructure;
        }

        return LexError.UnsupportedType;
    } else {
        std.debug.print("Entered CombineScope with null feet and inch. CombineScope requries there to be a non null feet or inch value", .{});

        return LexError.InvalidStructure;
    }
}

fn fractionScope(
    allocator: *std.mem.Allocator,
    context: *Context,
    start_index: u32,
) !*TypePayload {
    const numerator = context.copyFromToCurrent(start_index);

    if (context.takeChar() != '/') {
        std.debug.print("Context is expected to be on '/' char when entering FractionScope\n", .{});

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

    return payload;
}

fn valueTypeScope(
    allocator: *std.mem.Allocator,
    context: *Context,
    start_index: u32,
) LexError!*TypePayload {
    const value = context.copyFromToCurrent(start_index);
    const char = context.takeChar();

    switch (char) {
        '\'' => {
            if (!context.isEof() and context.takeChar() != ' ') {
                std.debug.print("Expected end of feet valueTypeScope here -> {any}\n", .{context.copyFromToCurrent(start_index)});

                return LexError.InvalidStructure;
            }

            const next = context.peek();

            if (next >= '0' and next <= '9') {
                return try combineScope(allocator, context, null, value);
            } else {
                const payload = try allocator.create(TypePayload);
                payload.* = TypePayload{
                    .feet = value,
                };

                return payload;
            }
        },
        '\"' => {
            // Consume Space
            context.consumeChar();

            const payload = try allocator.create(TypePayload);
            payload.* = TypePayload{
                .inch = value,
            };

            return payload;
        },
        else => {
            std.debug.print("UnsupportedType \'{c}\' found while parsing value_type scope. At index {d}\n", .{ context.peek(), context.index });

            return LexError.UnsupportedType;
        },
    }
}

fn operatorScope(
    allocator: *std.mem.Allocator,
    context: *Context,
) !*TypePayload {
    // Divide symbol ÷ is two ascii characters and starts with 195.
    // So when we find 195 we know to take two characers
    const slice = if (context.peek() == 195) context.takeSlice(context.index + 2) else context.takeSlice(context.index + 1);

    const payload = try allocator.create(TypePayload);
    payload.* = TypePayload{
        .operator = slice,
    };

    const char = context.takeChar();
    if (char != ' ') {
        std.debug.print("OperatorScope -> Found '{d}', index: {d}\n", .{ char, context.index - 1 });

        return LexError.InvalidStructure;
    }

    return payload;
}

pub const TypePayload = union(enum) {
    number: []const u8,
    feet: []const u8,
    inch: []const u8,
    fraction: *Fraction,
    combine: *Combine,
    operator: []const u8,

    // TODO Can this be done in a better way
    pub fn destory(self: *TypePayload, allocator: *std.mem.Allocator) void {
        if (@as(TypePayload, self.*) == TypePayload.fraction) {
            allocator.destroy(self.fraction);
        }

        if (@as(TypePayload, self.*) == TypePayload.combine) {
            if (self.combine.fraction) |f| {
                f.destory(allocator);
            }

            allocator.destroy(self.combine);
        }

        allocator.destroy(self);
    }
};

pub const Fraction = struct {
    numerator: []const u8,
    denominator: []const u8,
};

pub const Combine = struct {
    feet: ?[]const u8,
    inch: ?[]const u8,
    fraction: ?*TypePayload,
};

pub const Token = struct {
    payload: *TypePayload,

    pub fn destory(self: *Token, allocator: *std.mem.Allocator) void {
        self.payload.destory(allocator);
        allocator.destroy(self);
    }
};

const LexError = error{ UnsupportedType, InvalidStructure, OutOfMemory };
