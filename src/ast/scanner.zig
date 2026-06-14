const std = @import("std");
const testing = std.testing;
const token = @import("token.zig");
const span = @import("span.zig");
const Token = token.Token;
const TokenType = token.TokenType;
const Literal = token.Literal;
const Span = span.Span;

pub const ScannerError = struct {
    message: []const u8,
    span: Span,
};

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
        try self.addToken(.EOF, .none);
        return self.tokens;
    }

    fn scanToken(self: *Scanner) !void {
        switch (self.advance()) {
            // Single-char only
            '(' => try self.addToken(.LEFT_PAREN, .none),
            ')' => try self.addToken(.RIGHT_PAREN, .none),
            '{' => try self.addToken(.LEFT_BRACE, .none),
            '}' => try self.addToken(.RIGHT_BRACE, .none),
            ',' => try self.addToken(.COMMA, .none),
            '.' => try self.addToken(.DOT, .none),
            '*' => try self.addToken(.STAR, .none),
            ';' => try self.addToken(.SEMICOLON, .none),

            // Single- or multiple-char
            '+' => try self.addToken(if (self.match('=')) .PLUS_EQUAL else .PLUS, .none),
            '-' => try self.addToken(if (self.match('=')) .MINUS_EQUAL else .MINUS, .none),
            '=' => try self.addToken(if (self.match('=')) .EQUAL_EQUAL else .EQUAL, .none),
            '!' => try self.addToken(if (self.match('=')) .BANG_EQUAL else .BANG, .none),
            '>' => try self.addToken(if (self.match('=')) .GREATER_EQUAL else .GREATER, .none),
            '<' => try self.addToken(if (self.match('=')) .LESS_EQUAL else .LESS, .none),

            // Comment or division
            '/' => if (self.match('/')) self.comment() else try self.addToken(.SLASH, .none),

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
        var found_dot = false;
        while (!self.isAtEnd()) : (self.current += 1) {
            const c = self.peek();

            if (c == '.' and !found_dot) {
                found_dot = true;
                continue;
            }

            if (c < '0' and c > '9') {
                break;
            }
        }

        if (found_dot) {
            const val = try std.fmt.parseFloat(f64, self.lexeme());
            try self.addToken(.FLOAT, .{ .float = val });
        } else {
            const val = try std.fmt.parseInt(i64, self.lexeme(), 0);
            try self.addToken(.INT, .{ .int = val });
        }
    }

    fn identifier(self: *Scanner) !void {
        while (!self.isAtEnd()) {
            const c = self.peek();
            switch (c) {
                '0'...'9', 'a'...'z', 'A'...'Z', '_' => self.current += 1,
                else => break,
            }
        }

        const ident = self.lexeme();
        const keyword = Self.keyword_map.get(ident);

        if (keyword) |kw| {
            try self.addToken(kw, .none);
        } else {
            try self.addToken(.IDENT, .{ .string = ident });
        }
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

fn testScanner(input: []const u8, expected: []Token) void {
    input;
    expected;
}

test "identifiers" {
    testScanner(
        "come stay for a while",
        &.{
            .{ .type = .IDENT, .lexeme = "come", .literal = .{ .string = "come" } },
        },
    );
}
