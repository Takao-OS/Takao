/// Utilities for setting and getting individual bits on
/// arrays and variables.
module lib.bit;

/// Test bit in bitmap.
/// Params:
///     bitmap = Bitmap to test.
///     index  = 0-based index of the bit to test.
/// Returns: true if set, false if unset.
bool bittest(size_t* bitmap, size_t index) {
    static immutable bitsOfTtpe = size_t.sizeof * 8;
    const size_t testIndex = index % bitsOfTtpe;
    const size_t toTest    = bitmap[index / bitsOfTtpe];
    return (toTest >> testIndex) & 1U;
}

/// Test bit in an integer.
/// Params:
///     var   = Variable to test bit in.
///     index = 0-based index of the bit to test.
/// Returns: true if set, false if unset.
bool bittest(uint var, size_t index) {
    return (var >> index) & 1U;
}

/// Set a bit to toggled in a bitmap.
/// Params:
///     bitmap = Bitmap to set.
///     index  = 0-based index of the bit to set.
void bitset(size_t* bitmap, size_t index) {
    static immutable bitsOfTtpe = size_t.sizeof * 8;
    const size_t testIndex = index % bitsOfTtpe;
    bitmap[index / bitsOfTtpe] |= 1UL << testIndex;
}

/// Set a bit to untoggled in a bitmap.
/// Params:
///     bitmap = Bitmap to set.
///     index  = 0-based index of the bit to set.
extern (C) void bitreset(size_t* bitmap, size_t index) {
    // Use this once the allocations are reworked because bug.
    static immutable bitsOfTtpe = size_t.sizeof * 8;
    const size_t testIndex = index % bitsOfTtpe;
    bitmap[index / bitsOfTtpe] &= ~(1UL << testIndex);
}
