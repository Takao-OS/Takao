module lib.alloc;

import memory.physical;
import memory.virtual;
import lib.math;
import lib.glue;

T* newObj(T, A...)(A args) {
    auto size = divRoundUp(T.sizeof, PAGE_SIZE);
    auto ptr  = cast(T*)(pmmAllocAndZero(size) + MEM_PHYS_OFFSET);
    assert(ptr != null);

    static if (__traits(compiles, ptr.__ctor(args))) {
        ptr.__ctor(args);
    }

    return ptr;
}

void delObj(T)(T* object) {
    auto size = divRoundUp(T.sizeof, PAGE_SIZE);
    auto ptr  = cast(void*)object - MEM_PHYS_OFFSET;
    assert(ptr != null);

    static if (__traits(compiles, object.__dtor())) {
        object.__dtor();
    }

    pmmFree(ptr, size);
}

struct ArrayAllocMetadata {
    size_t pages;
    size_t count;
}

size_t getArraySize(void* ptr) {
    auto meta = cast(ArrayAllocMetadata*)(ptr - PAGE_SIZE);
    return meta.count;
}

T* newArray(T)(size_t count = 0) {
    auto pageCount = divRoundUp(T.sizeof * count, PAGE_SIZE);
    auto ptr = pmmAllocAndZero(pageCount + 1);
    assert(ptr != null);

    ptr += MEM_PHYS_OFFSET;

    auto meta = cast(ArrayAllocMetadata*)ptr;
    ptr += PAGE_SIZE;

    meta.pages = pageCount;
    meta.count = count;

    return cast(T*)ptr;
}

int resizeArray(T)(T** oldPtr, long diff) {
    auto meta = cast(ArrayAllocMetadata*)((cast(void*)*oldPtr) - PAGE_SIZE);

    size_t newCount;

    if ((diff + cast(long)meta.count) < 0) {
        newCount = 0;
    } else {
        newCount = cast(size_t)(diff + cast(long)meta.count);
    }

    return resizeArrayAbs(oldPtr, newCount);
}

int resizeArrayAbs(T)(T** oldPtr, size_t newCount) {
    auto pageCount = divRoundUp(T.sizeof * newCount, PAGE_SIZE);
    auto meta      = cast(ArrayAllocMetadata*)((cast(void*)*oldPtr) - PAGE_SIZE);

    if (meta.pages == pageCount) {
        meta.count = newCount;
        return 0;
    } else if (meta.pages > pageCount) {
        auto ptr = cast(void*)*oldPtr;
        ptr += (pageCount * PAGE_SIZE) - MEM_PHYS_OFFSET;
        pmmFree(ptr, meta.pages - pageCount);
        meta.pages = pageCount;
        meta.count = newCount;
        return 0;
    } else /* if (meta.pages < pageCount) */ {
        auto ptr = newArray!T(newCount);
        memcpy(ptr, *oldPtr, meta.pages * PAGE_SIZE);
        delArray(*oldPtr);
        *oldPtr = ptr;
        return 0;
    }
}

void delArray(void *ptr) {
    auto meta = cast(ArrayAllocMetadata*)(ptr - PAGE_SIZE);

    ptr -= MEM_PHYS_OFFSET;
    ptr -= PAGE_SIZE;

    pmmFree(ptr, meta.pages + 1);
}
