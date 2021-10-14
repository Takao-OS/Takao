/// Final allocator of the kernel for general purpose allocations, when
/// its not required for the memory to be physical, or have any weird
/// conditions.
module memory.alloc;

import memory.physical: blockSize, allocatePhysicalAndZero, freePhysical;
import lib.math:        divRoundUp;

private struct ArrayAllocMetadata {
    size_t pages;
    size_t count;
}

size_t getAllocationSize(void* ptr) {
    auto meta = cast(ArrayAllocMetadata*)(ptr - blockSize);
    return meta.count;
}

/// Allocate memory space for the passed sizes.
/// Params:
///     count = Count of items to allocate for.
/// Returns: Pointer to allocated space or null on failure.
T* allocate(T = ubyte)(size_t count = 1) {
    auto pageCount = divRoundUp(T.sizeof * count, blockSize);
    auto ptr = allocatePhysicalAndZero(pageCount + 1);
    if (ptr == null) {
        return null;
    }

    auto meta = cast(ArrayAllocMetadata*)ptr;
    ptr += blockSize;

    meta.pages = pageCount;
    meta.count = count;

    return cast(T*)ptr;
}

/// Resize a pre-existing allocation using relative differences.
/// Params:
///     oldPtr = Pointer to reallocate, might be modified by the function.
///     diff = Signed difference in the ammount of items allocated.
/// Returns: 0 on success, other values for failure.
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

/// Resize a pre-existing allocation using absolute differences.
/// Params:
///     oldPtr = Pointer to reallocate, might be modified by the function.
///     newCount = Ammount of items allocated.
/// Returns: 0 on success, other values for failure.
int resizeAllocationAbs(T)(T** oldPtr, size_t newCount) {
    auto pageCount = divRoundUp(T.sizeof * newCount, blockSize);
    auto meta      = cast(ArrayAllocMetadata*)((cast(void*)*oldPtr) - blockSize);

    if (meta.pages == pageCount) {
        meta.count = newCount;
        return 0;
    } else if (meta.pages > pageCount) {
        auto ptr = cast(void*)*oldPtr;
        ptr += (pageCount * blockSize);
        freePhysical(ptr, meta.pages - pageCount);
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

/// Free an allocation.
/// Params:
///     ptr = Pointer to free.
void free(void *ptr) {
    auto meta = cast(ArrayAllocMetadata*)(ptr - blockSize);
    ptr -= blockSize;
    freePhysical(ptr, meta.pages + 1);
}
