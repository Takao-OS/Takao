module lib.alignment;

size_t alignUp(size_t value, size_t alignment) {
    if ((value & (alignment - 1)) != 0) {
        value &= ~(alignment - 1);
        value += alignment;
    }
    return value;
}

size_t alignDown(size_t value, size_t alignment) {
    if ((value & (alignment - 1)) != 0) {
        value &= ~(alignment - 1);
    }
    return value;
}
