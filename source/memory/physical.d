module memory.physical;

import stivale;
import memory.virtual;
import lib.spinlock;

immutable PAGE_SIZE  = 0x1000;    // 4 KiB.
immutable ALLOC_BASE = 0x1000000; // 16 MiB.

private __gshared size_t   totalPages;
private __gshared size_t   stackSize;
private __gshared size_t*  stack;
private __gshared Spinlock lock;

void initPhysicalAllocator(StivaleMemmap memmap) {
    // Set the offsets we will use for the stack.
    stack = cast(size_t*)(ALLOC_BASE + MEM_PHYS_OFFSET);
        
    // Iterate over the memmap, align to ALLOC_BASE and count pages.
    foreach (i; 0..memmap.entries) {
        if (memmap.address[i].type != StivaleMemmapType.Usable) {
            continue;
        }

        if (alignMemmapEntry(&(memmap.address[i]), ALLOC_BASE)) {
            totalPages += memmap.address[i].size / PAGE_SIZE;
        }
    }

    // Now we know how many bytes we need for the stack.
    stackSize = totalPages * size_t.sizeof;

    // FIXME: Bad to assume having a contiguous chunk at that address.
    auto realBase = ALLOC_BASE + stackSize;
    realBase      = alignAddress(realBase, PAGE_SIZE);

    // Populate the stack with the free pages.
    foreach (i; 0..memmap.entries) {
        if (memmap.address[i].type != StivaleMemmapType.Usable) {
            continue;
        }

        if (alignMemmapEntry(&(memmap.address[i]), realBase)) {
            auto base = memmap.address[i].base;
            auto size = memmap.address[i].size;

            for (auto z = base; z < base + size; z += PAGE_SIZE) {
                *(stack) = z;
                stack++;
            }
        }
    }
    
    // Put stack to the beggining.
    stack = cast(size_t*)(ALLOC_BASE + MEM_PHYS_OFFSET);
}

private bool alignMemmapEntry(StivaleMemmapEntry* entry, size_t alignTo) {
    // Align to alignTo.        
    if (entry.base + entry.size <= alignTo) {
        return false; // Could not be successfully aligned.
    }

    if (entry.base < alignTo) {
        entry.size -= alignTo - entry.base;
        entry.base  = alignTo;
    }

    // Align to page boundaries.
    auto diff = entry.base % PAGE_SIZE;

    if (diff != 0) {
        entry.base = alignAddress(entry.base, PAGE_SIZE);
        entry.size -= diff;
    }

    if (entry.size < PAGE_SIZE) {
        return false; // Could not be successfully aligned.
    }

    diff = entry.size % PAGE_SIZE;

    if (diff != 0) {
        entry.size -= diff;
    }

    return true;
}

private size_t alignAddress(size_t addr, size_t alignTo) {
    auto result = addr;
    result &= ~(alignTo - 1);
    result += alignTo;
    return result;
}

void* allocPage() {
    lock.acquire();

    auto ret = cast(void*)(*stack);
    stack++;

    lock.release();
    return ret;
}

void* allocPageAndZero() {
    auto ret = cast(ulong*)(allocPage() + MEM_PHYS_OFFSET);

    foreach (i; 0..(PAGE_SIZE / ulong.sizeof)) {
        ret[i] = 0;
    }

    return cast(void*)(ret) - MEM_PHYS_OFFSET;
}

void freePage(void* page) {
    lock.acquire();

    stack--;
    *stack = cast(size_t)page;

    lock.release();
}
