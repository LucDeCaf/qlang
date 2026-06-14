pub const Span = struct {
    start: usize,
    end: usize,

    pub const ZERO: Span = Span{ .start = 0, .end = 0 };
};
