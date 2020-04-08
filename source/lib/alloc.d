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

struct ArrayAllocMetadata {
    size_t pages;
}

T* newArray(T)(size_t count) {
    auto size      = T.sizeof * count;
    auto pageCount = divRoundUp(size, PAGE_SIZE);

    void* ptr = pmmAllocAndZero(pageCount + 1);

    if (ptr == null) {
        return null;
    }

    ptr += MEM_PHYS_OFFSET;

    auto meta = cast(ArrayAllocMetadata*)ptr;
    ptr += PAGE_SIZE;

    meta.pages = pageCount;

    return cast(T*)ptr;
}

void delArray(void *ptr) {
    auto meta = cast(ArrayAllocMetadata*)ptr;

    ptr -= MEM_PHYS_OFFSET;

    pmmFree(ptr, meta.pages + 1);
}
