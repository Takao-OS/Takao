/// Functions called internally by the compiler generated code.
/// DO NOT CALL THIS EXPLICITLY. Thanks in advance <3.
module lib.glue;

deprecated {

/// Called when an `assert()` is generated.
/// Params:
///     exp  = Expression to fail the assert.
///     file = File where the expression was.
///     line = Line to fail the assert.
extern (C) void __assert(const char* exp, const char* file, uint line) {
    import lib.panic:  panic;
    import lib.string: fromCString;

    const expression = fromCString(exp);
    const path       = fromCString(file);
    panic("Assertion ", expression, " failed in ", path, " line ", line);
}

/// Emitted as an optimization for memory operations.
/// Params:
///     dest = Destination of the copy.
///     src  = Source of the copy.
///     n    = Numbers of bytes to copy.
/// Returns: Destination of the copy.
extern (C) void* memcpy(void* dest, const void* src, size_t n) {
    auto pdest = cast(ubyte*)dest;
    auto psrc  = cast(const ubyte*)src;

    for (size_t i = 0; i < n; i++) {
        pdest[i] = psrc[i];
    }

    return dest;
}

/// Emitted as an optimization for memory operations.
/// Params:
///     dest = Destination of the move.
///     src  = Source of the copy.
///     n    = Numbers of bytes to move.
/// Returns: Destination of the move.
extern (C) void* memmove(void* dest, const void* src, size_t n) {
    ubyte* pdest = cast(ubyte*)dest;
    const  psrc  = cast(ubyte*)src;

    if (src > dest) {
        for (size_t i = 0; i < n; i++) {
            pdest[i] = psrc[i];
        }
    } else if (src < dest) {
        for (size_t i = n; i > 0; i--) {
            pdest[i-1] = psrc[i-1];
        }
    }

    return dest;
}

/// Emitted as an optimization for memory operations.
/// Params:
///     s = Destination of the operation.
///     c = Value to set the memory region to.
///     n = Number of bytes to set.
/// Returns: Destination of the copy.
extern (C) void* memset(void* s, int c, ulong n) {
    auto pointer = cast(ubyte*)s;

    foreach (i; 0..n) {
        pointer[i] = cast(ubyte)c;
    }

    return s;
}

/// Emitted as an optimization for memory operations.
/// Params:
///     s1 = First memory address to compare.
///     s2 = Second memory address to compare.
///     n  = Number of bytes to compare.
/// Returns: 0 if equal, -1 if `s1` is greater, 1 if `s2` is greater.
extern (C) int memcmp(const void *s1, const void *s2, size_t n) {
    auto p1 = cast(ubyte*)s1;
    auto p2 = cast(ubyte*)s2;

    for (size_t i = 0; i < n; i++) {
        if (p1[i] != p2[i])
            return p1[i] < p2[i] ? -1 : 1;
    }

    return 0;
}

}
