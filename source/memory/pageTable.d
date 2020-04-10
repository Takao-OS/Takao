module memory.pageTable;

import system.cpu;
import memory.physical;
import memory.virtual;
import lib.lock;
import lib.stivale;

private immutable PT_ENTRIES = 512;
private immutable PT_PRESENT = 1;

size_t* findOrAllocTable(size_t* parent, size_t index, size_t flags) {
    auto ret = findTable(parent, index);

    if (ret == null) {
        ret = cast(size_t*)(pmmAllocAndZero(1) + MEM_PHYS_OFFSET);
        parent[index] = (cast(size_t)ret - MEM_PHYS_OFFSET) | flags;
    }

    return ret;
}

size_t* findTable(size_t* parent, size_t index) {
    if (parent[index] & PT_PRESENT) {
        // Remove flags and take address.
        return cast(size_t*)((parent[index] & ~(0xFFF)) + MEM_PHYS_OFFSET);
    } else {
        return null;
    }
}

void cleanTable(size_t* table) {
    for (size_t i = 0;; i++) {
        if (i == PT_ENTRIES) {
            pmmFree(cast(void*)(table) - MEM_PHYS_OFFSET, 1);
        } else if (table[i] & PT_PRESENT) {
            return;
        }
    }
}
