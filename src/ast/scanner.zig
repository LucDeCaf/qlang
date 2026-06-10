const std = @import("std");
const token = @import("token.zig");
const span = @import("span.zig");
const Token = token.Token;
const TokenType = token.TokenType;
const Literal = token.Literal;
const Span = span.Span;

pub const Scanner = struct {
    alloc: std.mem.Allocator,
    source: []u8,

    tokens: std.ArrayList(Token),
    errors: std.ArrayList(ScannerError),
    start: usize,
    current: usize,

    const keyword_map = std.StaticStringMap(TokenType).initComptime(.{
        .{ "let", TokenType.LET },
        .{ "if", TokenType.IF },
        .{ "else", TokenType.ELSE },
        .{ "for", TokenType.FOR },
        .{ "while", TokenType.WHILE },
        .{ "func", TokenType.FUNC },
        .{ "return", TokenType.RETURN },
        .{ "break", TokenType.BREAK },
        .{ "continue", TokenType.CONTINUE },
    });

    const Self = @This();

    pub fn init(alloc: std.mem.Allocator, source: []u8) Self {
        return Self{
            .alloc = alloc,
            .source = source,
            .tokens = .empty,
            .start = 0,
            .current = 0,
        };
    }

    pub fn scanTokens(self: *Self) !std.ArrayList(Token) {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scanToken();
        }
        try self.addToken(.EOF, .void);
        return self.tokens;
    }

    fn scanToken(self: *Scanner) !void {
        switch (self.advance()) {
            // Single-char only
            '(' => try self.addToken(.LEFT_PAREN, .void),
            ')' => try self.addToken(.RIGHT_PAREN, .void),
            '{' => try self.addToken(.LEFT_BRACE, .void),
            '}' => try self.addToken(.RIGHT_BRACE, .void),
            ',' => try self.addToken(.COMMA, .void),
            '.' => try self.addToken(.DOT, .void),
            '*' => try self.addToken(.STAR, .void),
            ';' => try self.addToken(.SEMICOLON, .void),

            // Single- or multiple-char
            '+' => try self.addToken(if (self.match('=')) .PLUS_EQUAL else .PLUS, .void),
            '-' => try self.addToken(if (self.match('=')) .MINUS_EQUAL else .MINUS, .void),
            '=' => try self.addToken(if (self.match('=')) .EQUAL_EQUAL else .EQUAL, .void),
            '!' => try self.addToken(if (self.match('=')) .BANG_EQUAL else .BANG, .void),
            '>' => try self.addToken(if (self.match('=')) .GREATER_EQUAL else .GREATER, .void),
            '<' => try self.addToken(if (self.match('=')) .LESS_EQUAL else .LESS, .void),

            // Comment or division
            '/' => if (self.match('/')) self.comment() else try self.addToken(.SLASH, .void),

            // Whitespace
            ' ', '\t', '\r', '\n' => {},

            // Literals
            '"' => try self.string(),
            '0'...'9' => try self.number(),
            'A'...'Z', 'a'...'z', '_' => try self.identifier(),

            else => self.addError("Unexpected character."),
        }
    }

    fn addToken(self: *Scanner, token_type: TokenType, literal: Literal) !void {
        try self.tokens.append(self.alloc, Token{
            .type = token_type,
            .literal = literal,
            .lexeme = self.lexeme(),
            .span = self.span(),
        });
    }

    fn addError(self: *Scanner, message: []const u8) void {
        try self.errors.append(self.alloc, ScannerError{
            .message = message,
            .span = self.span(),
        });
    }

    fn comment(self: *Scanner) void {
        self.consumeUntil('\n');
        // Comment may be on last line in the file and therefore has no newline
        if (self.prev() == '\n') self.line += 1;
    }

    fn string(self: *Scanner) !void {
        // First '"' is already skipped; for empty strings c may be '"' already.
        var c = self.advance();
        while (!self.isAtEnd() and c != '"') {
            c = self.advance();
        }

        // Reached EOF without terminating
        if (self.isAtEnd() and c != '"') {
            try self.addError("Unterminated string literal.");
            return;
        }

        try self.addToken(.STRING, .{ .string = self.lexeme() });
    }

    fn number(self: *Scanner) !void {
        // TODO
    }

    fn identifier(self: *Scanner) !void {
        // TODO
    }

    fn advance(self: *Scanner) u8 {
        const c = self.source[self.current];
        self.current += 1;
        return c;
    }

    fn consumeUntil(self: *Scanner, until: u8) void {
        while (!self.isAtEnd() and self.advance() != until) {}
    }

    fn peek(self: Scanner) u8 {
        return self.source[self.current];
    }

    fn match(self: *Scanner, expected: u8) bool {
        if (self.isAtEnd()) return false;

        if (self.peek() != expected) return false;

        self.current += 1;
        return true;
    }

    fn span(self: Scanner) Span {
        return .{ .start = self.start, .end = self.end };
    }

    fn lexeme(self: Scanner) []const u8 {
        return self.source[self.start..self.current];
    }

    fn isAtEnd(self: Self) bool {
        return self.current >= self.source.len;
    }
};

pub const ScannerError = struct {
    message: []const u8,
    span: Span,
};
