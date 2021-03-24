module memory.physical;

import kernelprotocol: KernelMemoryMap;
import lib.lock;
import lib.alignment;
import lib.math: divRoundUp;
import lib.bit: bittest, bitset, bitreset;

__gshared extern extern (C) void* kernelTop;

immutable size_t PAGE_SIZE = 0x1000;

private __gshared size_t  allocBase;
private __gshared size_t  highestPage;
private __gshared size_t* bitmap;
private __gshared Lock    pmmLock;
private __gshared size_t  lastUsedIndex = 0;

void initPhysicalAllocator(KernelMemoryMap memmap) {
    // First, calculate how big the bitmap needs to be.
    for (size_t i = 0; i < memmap.entryCount; i++) {
        ptrdiff_t top = memmap.entries[i].base + memmap.entries[i].size;

        if (top > highestPage) {
            highestPage = top;
        }
    }

    size_t bitmapSize = divRoundUp(highestPage, PAGE_SIZE) / 8;

    // Second, find a location with enough free pages to host the bitmap.
    for (size_t i = 0; i < memmap.entryCount; i++) {
        if (memmap.entries[i].size >= bitmapSize) {
            bitmap = cast(size_t*)(memmap.entries[i].base);

            // Initialise entire bitmap to 1 (non-free)
            auto a = cast(ubyte*)bitmap;
            foreach (j; 0..bitmapSize) {
                a[j] = 0xff;
            }

            memmap.entries[i].size -= bitmapSize;
            memmap.entries[i].base += bitmapSize;

            break;
        }
    }

    // Third, populate free bitmap entries according to memory map.
    for (size_t i = 0; i < memmap.entryCount; i++) {
        for (ptrdiff_t j = 0; j < memmap.entries[i].size; j += PAGE_SIZE) {
            bitreset(bitmap, (memmap.entries[i].base + j) / PAGE_SIZE);
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
                return cast(void*)(page * PAGE_SIZE);
            }
        } else {
            p = 0;
        }
    }
    return null;
}

void* pmmAlloc(size_t count) {
    pmmLock.acquire();

    size_t l = lastUsedIndex;
    void* ret = innerAlloc(count, highestPage / PAGE_SIZE);
    if (ret == null) {
        lastUsedIndex = 0;
        ret = innerAlloc(count, l);
    }

    pmmLock.release();
    return ret;
}
 
void* pmmAllocAndZero(size_t count) {
    auto ret = cast(ulong*)(pmmAlloc(count));

    foreach (i; 0..((count * PAGE_SIZE) / ulong.sizeof)) {
        ret[i] = 0;
    }

    return cast(void*)(ret);
}


void pmmFree(void* ptr, size_t count) {
    pmmLock.acquire();

    size_t page = cast(size_t)ptr / PAGE_SIZE;
    foreach (size_t i; page..(page + count)) {
        bitreset(bitmap, i);
    }

    pmmLock.release();
}
