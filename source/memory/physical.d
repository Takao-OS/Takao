/// Utilities for physical memory tracking and allocation.
module memory.physical;

import kernelprotocol: KernelMemoryMap;
import lib.lock:       Lock;
import lib.alignment:  alignUp, alignDown;
import lib.math:       divRoundUp;
import lib.bit:        bittest, bitset, bitreset;

private shared extern extern (C) void* kernelTop;

immutable blockSize = 0x1000; /// Size of the minimum block allocated.

/// Physical allocator.
struct PhysicalAllocator {
    private size_t  lowestPage;
    private size_t  highestPage;
    private size_t* bitmap;
    private Lock    lock;
    private size_t  lastUsedIndex;

    /// Construct the physical memory manager.
    this(ref KernelMemoryMap memmap) {
        // First, calculate how big the bitmap needs to be.
        for (size_t i = 0; i < memmap.entryCount; i++) {
            const top = memmap.entries[i].base + memmap.entries[i].size;
            if (top > highestPage) {
                highestPage = top;
            }
        }
        const bitmapSize = divRoundUp(highestPage, blockSize) / 8;

        // Second, find a location with enough free pages to host the bitmap.
        foreach (i; 0..memmap.entryCount) {
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
        foreach (i; 0..memmap.entryCount) {
            for (ptrdiff_t j = 0; j < memmap.entries[i].size; j += blockSize) {
                bitreset(bitmap, (memmap.entries[i].base + j) / blockSize);
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

    /// Allocate some memory blocks.
    /// Params:
    ///     count = Count of blocks to alloc.
    /// Returns: The address of the block, or `null` if error.
    void* alloc(size_t count) {
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

    /// Allocate some memory blocks and zero them out.
    /// Params:
    ///     count = Count of blocks to alloc.
    /// Returns: The address of the block, or `null` if error.
    void* allocAndZero(size_t count) {
        auto ret = cast(ulong*)(alloc(count));

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
    void free(void* ptr, size_t count) {
        lock.acquire();

        size_t page = cast(size_t)ptr / blockSize;
        foreach (size_t i; page..(page + count)) {
            bitreset(bitmap, i);
        }

        lock.release();
    }
}
