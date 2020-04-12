module lib.glue;

import lib.string;
import lib.messages;

extern (C) __gshared void* _Dmodule_ref;

extern (C) void _Unwind_Resume(void *p) {
    panic("_Unwind_Resume(", cast(size_t)p, ") called");
}

extern (C) void _d_eh_personality() {
    panic("_d_eh_personality called");
}

extern (C) void __assert(const char* exp, const char* file, uint line) {
    panic("Assertion failed in '", fromCString(file), "' line ", line);
}

extern (C) void *memcpy(void* dest, const void* src, size_t n) {
    auto pdest = cast(ubyte*)dest;
    auto psrc  = cast(const ubyte*)src;

    for (size_t i = 0; i < n; i++) {
        pdest[i] = psrc[i];
    }

    return dest;
}

extern (C) void* memset(void* s, int c, ulong n) {
    auto pointer = cast(ubyte*)s;

    foreach (i; 0..n) {
        pointer[i] = cast(ubyte)c;
    }

    return s;
}

extern (C) int memcmp(const void *s1, const void *s2, size_t n) {
    auto p1 = cast(ubyte*)s1;
    auto p2 = cast(ubyte*)s2;

    for (size_t i = 0; i < n; i++) {
        if (p1[i] != p2[i])
            return p1[i] < p2[i] ? -1 : 1;
    }

    return 0;
}
