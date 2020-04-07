module lib.alloc;

import memory.physical;
import memory.virtual;
import lib.math;

T* newObj(T, A...)(A args) {
    auto size = divRoundUp(T.sizeof, PAGE_SIZE);
    auto ptr  = cast(T*)(pmmAllocAndZero(size) + MEM_PHYS_OFFSET);

    static if (__traits(compiles, ptr.__ctor(args))) {
        ptr.__ctor(args);
    }

    return ptr;
}

void delObj(T)(T* object) {
    auto size = divRoundUp(T.sizeof, PAGE_SIZE);
    auto ptr  = cast(void*)object - MEM_PHYS_OFFSET;

    static if (__traits(compiles, object.__dtor())) {
        object.__dtor();
    }

    pmmFree(ptr, size);
}
