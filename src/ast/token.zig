const std = @import("std");
const Span = @import("span.zig").Span;

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    literal: Literal,
    span: Span,

    const Self = @This();

    pub fn from(type: TokenType, value: anytype) Self {
        const literal = Literal.from(value);
        return .{
            .type = type,
            .lexeme = lexeme,
            .literal = literal,
            .span = span,
        };
    }

    pub fn print(self: Self) void {
        switch (self.literal) {
            .void => std.debug.print("{s} ", .{@tagName(self.type)}),
            .int => |val| std.debug.print("({s}: {d}) ", .{ @tagName(self.type), val }),
            .float => |val| std.debug.print("({s}: {d:.2})", .{ @tagName(self.type), val }),
            .string => |val| std.debug.print("({s}: {s})", .{ @tagName(self.type), val }),
        }
    }
};

pub const Literal = union(enum) {
    void, // Use Literal.void instead of ?Literal
    int: i64,
    float: f64,
    string: []const u8,

    pub fn from(comptime value: anytype) Literal {
        return switch (@TypeOf(value)) {
            .comptime_int => .{ .int = value },
            .comptime_float => .{ .float = value },
        };
    }
};

pub const TokenType = enum {
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    STAR,
    SEMICOLON,

    PLUS,
    PLUS_EQUAL,
    MINUS,
    MINUS_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    BANG,
    BANG_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,

    SLASH,

    IDENTIFIER,
    STRING,
    INT,
    FLOAT,

    LET,
    IF,
    ELSE,
    FOR,
    WHILE,
    FUNC,
    RETURN,
    BREAK,
    CONTINUE,

    EOF,
};
