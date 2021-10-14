/// Utilities for physical memory tracking and allocation.
module memory.physical;

import kernelprotocol: KernelMemoryEntry;
import lib.lock:       Lock;
import lib.alignment:  alignUp, alignDown;
import lib.math:       divRoundUp;
import lib.bit:        bittest, bitset, bitreset;

private shared extern extern (C) void* kernelTop;

immutable blockSize = 0x1000; /// Size of the minimum block allocated.

private __gshared size_t  lowestPage;
private __gshared size_t  highestPage;
private __gshared size_t* bitmap;
private __gshared Lock    lock;
private __gshared size_t  lastUsedIndex;

/// Construct the physical memory manager.
void initPhysicalAllocator(const KernelMemoryEntry[] memmap) {
    // First, calculate how big the bitmap needs to be.
    foreach (ref entry; memmap) {
        const top = entry.base + entry.size;
        if (top > highestPage) {
            highestPage = top;
        }
    }
    const bitmapSize = divRoundUp(highestPage, blockSize) / 8;

    // Second, find a location with enough free pages to host the bitmap.
    size_t bitmapEntry;
    size_t realSize;
    size_t realBase;
    foreach (i; 0..memmap.length) {
        if (!memmap[i].isFree) {
            continue;
        }
        if (memmap[i].size >= bitmapSize) {
            bitmapEntry = i;
            bitmap      = cast(size_t*)(memmap[i].base);
            realSize    = memmap[i].size - bitmapSize;
            realBase    = memmap[i].base + bitmapSize;

            // Initialise entire bitmap to 1 (non-free)
            auto a = cast(ubyte*)bitmap;
            foreach (j; 0..bitmapSize) {
                a[j] = 0xff;
            }

            break;
        }
    }

    // Third, populate free bitmap entries according to memory map.
    foreach (i; 0..memmap.length) {
        if (memmap[i].isFree) {
            size_t base;
            size_t size;
            if (i == bitmapEntry) {
                size = realSize;
                base = realBase;
            } else {
                size = memmap[i].size;
                base = memmap[i].base;
            }
            for (ptrdiff_t j = 0; j < size; j += blockSize) {
                bitreset(bitmap, (base + j) / blockSize);
            }
        } else {
            for (ptrdiff_t j = 0; j < memmap[i].size; j += blockSize) {
                bitset(bitmap, (memmap[i].base + j) / blockSize);
            }
        }
    }
}

private void* innerAlloc(size_t count, size_t limit) {
    size_t p = 0;
    while (lastUsedIndex < limit) {
        if (!bittest(bitmap, lastUsedIndex++)) {
            if (++p == count) {
                size_t page = lastUsedIndex - count;
                foreach (size_t i; page..lastUsedIndex) {
                    bitset(bitmap, i);
                }
                return cast(void*)(page * blockSize);
            }
        } else {
            p = 0;
        }
    }

    return null;
}

/// Allocate some physical memory blocks.
/// Params:
///     count = Count of blocks to alloc.
/// Returns: The address of the block, or `null` if error.
void* allocatePhysical(size_t count) {
    lock.acquire();

    size_t l = lastUsedIndex;
    void* ret = innerAlloc(count, highestPage / blockSize);
    if (ret == null) {
        lastUsedIndex = 0;
        ret = innerAlloc(count, l);
    }

    lock.release();
    return ret;
}

/// Allocate some physical memory blocks and zero them out.
/// Params:
///     count = Count of blocks to alloc.
/// Returns: The address of the block, or `null` if error.
void* allocatePhysicalAndZero(size_t count) {
    auto ret = cast(ulong*)(allocatePhysical(count));

    foreach (i; 0..((count * blockSize) / ulong.sizeof)) {
        ret[i] = 0;
    }

    return cast(void*)(ret);
}

/// Free a memory block.
/// Params:
///     ptr   = Pointer to free.
///     count = Count of blocks to free.
/// Returns: The address of the block, or `null` if error.
void freePhysical(void* ptr, size_t count) {
    lock.acquire();

    size_t page = cast(size_t)ptr / blockSize;
    foreach (size_t i; page..(page + count)) {
        bitreset(bitmap, i);
    }

    lock.release();
}
