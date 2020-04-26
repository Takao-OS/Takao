module memory.physical;

import stivale;
import memory.virtual;
import lib.lock;
import lib.alignment;
import lib.bit;

__gshared extern extern (C) void* kernelTop;

immutable size_t PAGE_SIZE  = 0x1000;

private __gshared size_t  allocBase;
private __gshared size_t  highestPage;
private __gshared size_t* bitmap;
private __gshared Lock    pmmLock;
private __gshared size_t  lastUsedIndex = 0;

void initPhysicalAllocator(StivaleMemmap memmap) {
    allocBase = (cast(size_t)&kernelTop) - KERNEL_PHYS_OFFSET;

    foreach (i; 0..memmap.entries) {
        if (memmap.address[i].type != StivaleMemmapType.Usable) {
            continue;
        }

        auto base = alignUp(memmap.address[i].base, PAGE_SIZE);
        auto size = memmap.address[i].size - (base - memmap.address[i].base);
        size      = alignDown(size, PAGE_SIZE);
        auto top  = base + size;

        if (base < allocBase) {
            if (top > allocBase) {
                size -= allocBase - base;
                base  = allocBase;
            } else {
                memmap.address[i].type = StivaleMemmapType.Unusable;
                continue;
            }
        }

        memmap.address[i].base = base;
        memmap.address[i].size = size;

        if (top > highestPage) {
            highestPage = top;
        }
    }

    size_t bitmapSize = (highestPage / PAGE_SIZE) / 8;

    // Find a hole for the stupid bitmap.
    foreach (i; 0..memmap.entries) {
        if (memmap.address[i].type != StivaleMemmapType.Usable) {
            continue;
        }

        if (memmap.address[i].size >= bitmapSize) {
            bitmap = cast(size_t*)(memmap.address[i].base + MEM_PHYS_OFFSET);

            memmap.address[i].size -= bitmapSize;
            memmap.address[i].base += bitmapSize;

            // Set all bitmap to 1
            foreach (size_t j; 0..(bitmapSize / size_t.sizeof)) {
                bitmap[j] = ~cast(size_t)0;
            }

            break;
        }
    }

    // Populate the stupid bitmap.
    foreach (i; 0..memmap.entries) {
        if (memmap.address[i].type != StivaleMemmapType.Usable) {
            continue;
        }

        for (size_t j = 0; j < memmap.address[i].size; j += PAGE_SIZE) {
            size_t page = (memmap.address[i].base + j) / PAGE_SIZE;
            btr(bitmap, page);
        }
    }
}

private void* innerAlloc(size_t count, size_t limit) {
    size_t p = 0;
    while (lastUsedIndex < limit) {
        if (!bt(bitmap, lastUsedIndex++)) {
            if (++p == count) {
                size_t page = lastUsedIndex - count;
                foreach (size_t i; page..lastUsedIndex) {
                    bts(bitmap, i);
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
    auto ret = cast(ulong*)(pmmAlloc(count) + MEM_PHYS_OFFSET);

    foreach (i; 0..(count * (PAGE_SIZE / ulong.sizeof))) {
        ret[i] = 0;
    }

    return cast(void*)(ret) - MEM_PHYS_OFFSET;
}


void pmmFree(void* ptr, size_t count) {
    pmmLock.acquire();

    size_t page = cast(size_t)ptr / PAGE_SIZE;
    foreach (size_t i; page..(page + count)) {
        btr(bitmap, i);
    }

    pmmLock.release();
}
