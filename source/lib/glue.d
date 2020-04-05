module glue;

import lib.debugging: panic;

extern (C) void __assert(const char* exp, const char* file, uint line) {
    panic("In file '%s', line '%u'\n> %s\nFailed assertion", file, line, exp);
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
