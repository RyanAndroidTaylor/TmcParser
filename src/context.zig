const Token = @import("main.zig").Token;
const std = @import("std");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub fn Context() type {
    return struct {
        const Self = @This();

        index: u32,
        expression: [:0]const u8,

        pub fn init(expression: [:0]const u8) Self {
            return Self{
                .index = 0,
                .expression = expression,
            };
        }

        pub fn takeChar(self: *Self) u8 {
            const char = self.expression[self.index];

            self.index = self.index + 1;

            return char;
        }

        pub fn takeSlice(self: *Self, to: u32) []const u8 {
            const slice = self.expression[self.index..to];

            self.index = to;

            return slice;
        }

        pub fn consumeChar(self: *Self) void {
            self.index = self.index + 1;
        }

        pub fn peek(self: *Self) u8 {
            return self.expression[self.index];
        }

        pub fn peekAhead(self: *Self, amount: u32) u8 {
            return self.expression[self.index + amount];
        }

        pub fn copyFromToCurrent(self: *Self, from: u32) []const u8 {
            return self.expression[from..self.index];
        }

        pub fn copyFromToEof(self: *Self, from: u32) []const u8 {
            return self.expression[from..self.expression.len];
        }

        pub fn copySlice(self: *Self, from: u32, to: u32) []const u8 {
            return self.expression[from..to];
        }

        pub fn isEof(self: *Self) bool {
            return self.index >= self.expression.len;
        }
    };
}
