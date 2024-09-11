const std = @import("std");
const ArrayList = std.ArrayList;
const Token = @import("main.zig").Token;

pub const Context = struct {
    index: u32,
    expression: [:0]const u8,

    pub fn takeChar(self: *Context) u8 {
        const char = self.expression[self.index];

        self.index = self.index + 1;

        return char;
    }

    pub fn takeSlice(self: *Context, to: u32) []const u8 {
        const slice = self.expression[self.index..to];

        self.index = to;

        return slice;
    }

    pub fn consumeChar(self: *Context) void {
        self.index = self.index + 1;
    }

    pub fn peek(self: *Context) u8 {
        return self.expression[self.index];
    }

    pub fn peekAhead(self: *Context, amount: u32) u8 {
        return self.expression[self.index + amount];
    }

    pub fn copyFrom(self: *Context, from: u32) []const u8 {
        return self.expression[from..self.index];
    }

    pub fn copySlice(self: *Context, from: u32, to: u32) []const u8 {
        return self.expression[from..to];
    }

    pub fn isEof(self: *Context) bool {
        return self.index == self.expression.len;
    }

    pub fn destroy(self: *Context, allocator: *std.mem.Allocator) void {
        allocator.destroy(self);
    }
};
