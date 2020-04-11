module lib.alloc;

import memory.physical;
import memory.virtual;
import lib.math;
import lib.glue;

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

T* resizeArray(T)(T* oldPtr, size_t newCount) {
    auto size      = T.sizeof * newCount;
    auto pageCount = divRoundUp(size, PAGE_SIZE);
    auto meta      = cast(ArrayAllocMetadata*)oldPtr;

    if (meta.pages == pageCount) {
        return oldPtr;
    } else if (meta.pages > pageCount) {
        auto ptr = cast(void*)oldPtr + PAGE_SIZE;
        ptr += (pageCount * PAGE_SIZE) - MEM_PHYS_OFFSET;
        pmmFree(ptr, meta.pages - pageCount);
        meta.pages = pageCount;
        return oldPtr;
    } else if (meta.pages < pageCount) {
        auto ptr = newArray!T(newCount);
        memcpy(ptr, oldPtr, meta.pages * PAGE_SIZE);
        delArray(oldPtr);
        return ptr;
    }
}

void delArray(void *ptr) {
    auto meta = cast(ArrayAllocMetadata*)ptr;

    ptr -= MEM_PHYS_OFFSET;

    pmmFree(ptr, meta.pages + 1);
}
