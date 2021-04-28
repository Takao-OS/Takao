module memory.alloc;

import memory.physical: blockSize, PhysicalAllocator;
import lib.math:        divRoundUp;

private struct ArrayAllocMetadata {
    size_t pages;
    size_t count;
}

size_t getAllocationSize(void* ptr) {
    auto meta = cast(ArrayAllocMetadata*)(ptr - blockSize);
    return meta.count;
}

T* allocate(T = ubyte)(size_t count = 1) {
    auto pageCount = divRoundUp(T.sizeof * count, blockSize);
    auto ptr = PhysicalAllocator.allocAndZero(pageCount + 1);
    assert(ptr != null);

    auto meta = cast(ArrayAllocMetadata*)ptr;
    ptr += blockSize;

    meta.pages = pageCount;
    meta.count = count;

    return cast(T*)ptr;
}

int resizeAllocation(T)(T** oldPtr, long diff) {
    auto meta = cast(ArrayAllocMetadata*)((cast(void*)*oldPtr) - blockSize);

    size_t newCount;

    if ((diff + cast(long)meta.count) < 0) {
        newCount = 0;
    } else {
        newCount = cast(size_t)(diff + cast(long)meta.count);
    }

    return resizeAllocationAbs(oldPtr, newCount);
}

int resizeAllocationAbs(T)(T** oldPtr, size_t newCount) {
    auto pageCount = divRoundUp(T.sizeof * newCount, blockSize);
    auto meta      = cast(ArrayAllocMetadata*)((cast(void*)*oldPtr) - blockSize);

    if (meta.pages == pageCount) {
        meta.count = newCount;
        return 0;
    } else if (meta.pages > pageCount) {
        auto ptr = cast(void*)*oldPtr;
        ptr += (pageCount * blockSize);
        PhysicalAllocator.free(ptr, meta.pages - pageCount);
        meta.pages = pageCount;
        meta.count = newCount;
        return 0;
    } else /* if (meta.pages < pageCount) */ {
        auto ptr = cast(ubyte*)allocate!T(newCount);
        foreach (size_t c; 0..meta.pages * blockSize) {
            ptr[c] = (cast(ubyte*)*oldPtr)[c];
        }

        free(*oldPtr);
        *oldPtr = cast(T*)ptr;
        return 0;
    }
}

void free(void *ptr) {
    auto meta = cast(ArrayAllocMetadata*)(ptr - blockSize);
    ptr -= blockSize;
    PhysicalAllocator.free(ptr, meta.pages + 1);
}
