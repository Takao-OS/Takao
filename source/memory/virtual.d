module memory.virtual;

import system.cpu;
import memory.physical;
import lib.lock;
import stivale;

immutable MEM_PHYS_OFFSET    = 0xffff800000000000;
immutable KERNEL_PHYS_OFFSET = 0xffffffff80000000;

private immutable PT_PRESENT = 1 << 0;
private immutable PT_ENTRIES = 512;

size_t* findOrAllocPageTable(size_t* table, size_t index, size_t flags) {
    auto ret = findPageTable(table, index);

    if (ret == null) {
        ret = cast(size_t*)(pmmAllocAndZero(1) + MEM_PHYS_OFFSET);
        assert(cast(size_t)ret != MEM_PHYS_OFFSET);
        table[index] = (cast(size_t)ret - MEM_PHYS_OFFSET) | flags;
    }

    return ret;
}

size_t* findPageTable(size_t* table, size_t index) {
    if (table[index] & PT_PRESENT) {
        // Remove flags and take address.
        return cast(size_t*)((table[index] & ~(cast(size_t)0xfff)) + MEM_PHYS_OFFSET);
    } else {
        return null;
    }
}

void cleanPageTable(size_t* table) {
    for (size_t i = 0;; i++) {
        if (i == PT_ENTRIES) {
            pmmFree(cast(void*)(table) - MEM_PHYS_OFFSET, 1);
        } else if (table[i] & PT_PRESENT) {
            return;
        }
    }
}

struct AddressSpace {
    private Lock    lock;
    private size_t* pml4;

    this(StivaleMemmap memmap) {
        this.pml4 = cast(size_t*)(pmmAllocAndZero(1) + MEM_PHYS_OFFSET);

        // Map anything from 0 to 4 GiB starting from MEM_PHYS_OFFSET.
        for (size_t i = 0; i < 0x100000000; i += PAGE_SIZE) {
            this.mapPage(i, i, 0x03);
            this.mapPage(i, MEM_PHYS_OFFSET + i, 0x03);
        }

        for (size_t i = 0; i < 0x80000000; i += PAGE_SIZE) {
            this.mapPage(i, KERNEL_PHYS_OFFSET + i, 0x03);
        }

        // Map according to the memmap.
        for (auto i = 0; i < memmap.entries; i++) {
            auto base = memmap.address[i].base;
            auto size = memmap.address[i].size;

            size_t alignedBase = base - (base % PAGE_SIZE);
            size_t alignedSize = (size / PAGE_SIZE) * PAGE_SIZE;

            if (size % PAGE_SIZE) {
                alignedSize += PAGE_SIZE;
            }

            if (base % PAGE_SIZE) {
                alignedSize += PAGE_SIZE;
            }

            for (ulong j = 0; j * PAGE_SIZE < alignedSize; j++) {
                size_t addr = alignedBase + j * PAGE_SIZE;

                // Skip over first 4 GiB
                if (addr < 0x100000000) {
                    continue;
                }

                this.mapPage(addr, MEM_PHYS_OFFSET + addr, 0x03);
            }
        }
    }

    void setActive() {
        this.lock.acquire();
        writeCR3(cast(size_t)(this.pml4) - MEM_PHYS_OFFSET);
        this.lock.release();
    }

    void mapPage(size_t physicalAddress, size_t virtualAddress, size_t flags) {
        this.lock.acquire();

        // Calculate the indexes in the various tables using the virtual addr.
        auto pml4Entry = (virtualAddress & (cast(size_t)0x1ff << 39)) >> 39;
        auto pml3Entry = (virtualAddress & (cast(size_t)0x1ff << 30)) >> 30;
        auto pml2Entry = (virtualAddress & (cast(size_t)0x1ff << 21)) >> 21;
        auto pml1Entry = (virtualAddress & (cast(size_t)0x1ff << 12)) >> 12;

        // Find or create tables.
        size_t* pml3 = findOrAllocPageTable(this.pml4, pml4Entry, 0b111);
        size_t* pml2 = findOrAllocPageTable(pml3, pml3Entry, 0b111);
        size_t* pml1 = findOrAllocPageTable(pml2, pml2Entry, 0b111);

        // Set the entry as present and point it to the passed address.
        // Also set flags.
        pml1[pml1Entry] = physicalAddress | flags;

        this.lock.release();
    }

    void unmapPage(size_t virtualAddress) {
        this.lock.acquire();

        // Calculate the indexes in the various tables using the virtual addr.
        auto pml4Entry = (virtualAddress & (cast(size_t)0x1FF << 39)) >> 39;
        auto pml3Entry = (virtualAddress & (cast(size_t)0x1FF << 30)) >> 30;
        auto pml2Entry = (virtualAddress & (cast(size_t)0x1FF << 21)) >> 21;
        auto pml1Entry = (virtualAddress & (cast(size_t)0x1FF << 12)) >> 12;

        // Find or die if we dont find them.
        size_t* pml3 = findPageTable(this.pml4, pml4Entry);
        assert(pml3 != null);
        size_t* pml2 = findPageTable(pml3, pml3Entry);
        assert(pml2 != null);
        size_t* pml1 = findPageTable(pml2, pml2Entry);
        assert(pml1 != null);

        // Unmap.
        pml1[pml1Entry] = 0;

        // Cleanup.
        cleanPageTable(pml3);
        cleanPageTable(pml2);
        cleanPageTable(pml1);

        lock.release();
    }
}
