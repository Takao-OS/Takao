/// Utilities for aligning memory addresses to arbitrary boundaries.
module lib.alignment;

/// Align up an address to a memory alignment.
size_t alignUp(size_t value, size_t alignment) {
    if ((value & (alignment - 1)) != 0) {
        value &= ~(alignment - 1);
        value += alignment;
    }
    return value;
}

/// Align down an address to a memory alignment.
size_t alignDown(size_t value, size_t alignment) {
    if ((value & (alignment - 1)) != 0) {
        value &= ~(alignment - 1);
    }
    return value;
}
