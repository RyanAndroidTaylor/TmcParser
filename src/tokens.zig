const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Token = union(enum) {
    number: *NumberToken(),
    operator: *OperatorToken(),
    feet: *FeetToken(),
    inch: *InchToken(),
    fraction: *FractionToken(),
    combine: *CombineToken(),
    errorToken: *ErrorToken(),
};

pub fn NumberToken() type {
    return struct {
        const Self = @This();

        value: f32,
        start_index: u32,
        end_index: u32,

        pub fn inint(allocator: Allocator, value: f32, start_index: u32, end_index: u32) *Self {
            const number = allocator.create(Self) catch unreachable;

            number.* = Self{
                .value = value,
                .start_index = start_index,
                .end_index = end_index,
            };

            return number;
        }
    };
}

pub fn OperatorToken() type {
    return struct {
        const Self = @This();

        value: u8,
        index: u32,

        pub fn init(allocaotr: Allocator, value: u8, index: u32) Self {
            const operator = allocaotr.create(Self);

            operator.* = Self{
                .value = value,
                .index = index,
            };

            return operator;
        }
    };
}

// 12' || 12.5'
pub fn FeetToken() type {
    return struct {
        const Self = @This();

        value: f32,
        start_index: u32,
        end_index: u32,

        pub fn init(allocator: Allocator, value: f32, start_index: u32, end_index: u32) Self {
            const feet = allocator.create(Self);

            feet.* = Self{
                .value = value,
                .start_index = start_index,
                .end_index = end_index,
            };

            return feet;
        }
    };
}

pub fn InchToken() type {
    return struct {
        const Self = @This();

        value: f32,
        start_index: u32,
        end_index: u32,

        pub fn init(allocator: Allocator, value: f32, start_index: u32, end_index: u32) Self {
            const inch = allocator.create(Self);

            inch.* = Self{
                .value = value,
                .start_index = start_index,
                .end_index = end_index,
            };

            return inch;
        }
    };
}

pub fn FractionToken() type {
    return struct {
        const Self = @This();

        value: f32,
        start_index: u32,
        end_index: u32,

        pub fn init(allocator: Allocator, value: f32, start_index: u32, end_index: u32) Self {
            const fraction = allocator.create(Self);

            fraction.* = Self{
                .value = value,
                .start_index = start_index,
                .end_index = end_index,
            };
        }
    };
}

pub fn CombineToken() type {
    return struct {
        const Self = @This();

        value: f32,
        feet: ?FeetToken(),
        inch: ?InchToken(),
        fraction: ?FractionToken(),
        // As for now I don't see a reason to need start and end index

        pub fn init(allocator: Allocator, value: f32, feet: ?FeetToken, inch: ?InchToken, fraction: ?FractionToken) Self {
            const combine = allocator.create(Self);

            combine.* = Self{
                .value = value,
                .feet = feet,
                .inch = inch,
                .fraction = fraction,
            };

            return combine;
        }
    };
}

pub fn ErrorToken() type {
    return struct {
        const Self = @This();

        tokenize_error: TokenizeError,
        start_index: u32,
        end_index: u32,

        pub fn init(allocator: Allocator, tokenize_error: TokenizeError, start_index: u32, end_index: u32) Self {
            const error_token = allocator.create(Self);

            error_token.* = Self{
                .tokenize_error = tokenize_error,
                .start_index = start_index,
                .end_index = end_index,
            };

            return error_token;
        }
    };
}

// Might need to change to a union(enum) to be able to include extra data with errors
// but for now I don't see the need
pub const TokenizeError = enum {
    unexpected_space,
    incompatible_types,
};
