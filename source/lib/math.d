/// Nice to have math functions.
module lib.math;

/// Divide and round it up.
/// Params:
///     a = Numerator of the division.
///     b = Dividend of the division.
/// Returns: Rounded up division.
ulong divRoundUp(ulong a, ulong b) {
    return (a + (b - 1)) / b;
}
