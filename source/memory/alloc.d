module memory.alloc;

import memory.physical;
import lib.math;
import lib.glue;

private struct ArrayAllocMetadata {
    size_t pages;
    size_t count;
}

size_t getAllocationSize(void* ptr) {
    auto meta = cast(ArrayAllocMetadata*)(ptr - PAGE_SIZE);
    return meta.count;
}

T* allocate(T = ubyte)(size_t count = 1) {
    auto pageCount = divRoundUp(T.sizeof * count, PAGE_SIZE);
    auto ptr = pmmAllocAndZero(pageCount + 1);
    assert(ptr != null);

    auto meta = cast(ArrayAllocMetadata*)ptr;
    ptr += PAGE_SIZE;

    meta.pages = pageCount;
    meta.count = count;

    return cast(T*)ptr;
}

int resizeAllocation(T)(T** oldPtr, long diff) {
    auto meta = cast(ArrayAllocMetadata*)((cast(void*)*oldPtr) - PAGE_SIZE);

    size_t newCount;

    if ((diff + cast(long)meta.count) < 0) {
        newCount = 0;
    } else {
        newCount = cast(size_t)(diff + cast(long)meta.count);
    }

    return resizeAllocationAbs(oldPtr, newCount);
}

int resizeAllocationAbs(T)(T** oldPtr, size_t newCount) {
    auto pageCount = divRoundUp(T.sizeof * newCount, PAGE_SIZE);
    auto meta      = cast(ArrayAllocMetadata*)((cast(void*)*oldPtr) - PAGE_SIZE);

    if (meta.pages == pageCount) {
        meta.count = newCount;
        return 0;
    } else if (meta.pages > pageCount) {
        auto ptr = cast(void*)*oldPtr;
        ptr += (pageCount * PAGE_SIZE);
        pmmFree(ptr, meta.pages - pageCount);
        meta.pages = pageCount;
        meta.count = newCount;
        return 0;
    } else /* if (meta.pages < pageCount) */ {
        auto ptr = cast(ubyte*)allocate!T(newCount);
        foreach (size_t c; 0..meta.pages * PAGE_SIZE) {
            ptr[c] = (cast(ubyte*)*oldPtr)[c];
        }

        free(*oldPtr);
        *oldPtr = cast(T*)ptr;
        return 0;
    }
}

void free(void *ptr) {
    auto meta = cast(ArrayAllocMetadata*)(ptr - PAGE_SIZE);
    ptr -= PAGE_SIZE;
    pmmFree(ptr, meta.pages + 1);
}
