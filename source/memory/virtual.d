module memory.virtual;

import system.intrinsics;
import memory.physical;
import lib.lock;
import lib.stivale;

immutable MEM_PHYS_OFFSET    = 0xffff800000000000;
immutable KERNEL_PHYS_OFFSET = 0xffffffff80000000; 

private immutable PT_PRESENT = 1 << 0;
private immutable PT_ENTRIES = 512;

struct AddressSpace {
    private Lock    lock;
    private size_t* pml4;

    this(StivaleMemmap memmap) {
        this.pml4 = cast(size_t*)(allocPageAndZero() + MEM_PHYS_OFFSET);

        // Map anything from 0 to 4 GiB starting from MEM_PHYS_OFFSET. 
        for (size_t i = 0; i < 0x100000000; i += PAGE_SIZE) {
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
        auto pml4Entry = (virtualAddress & (cast(size_t)0x1FF << 39)) >> 39;
        auto pml3Entry = (virtualAddress & (cast(size_t)0x1FF << 30)) >> 30;
        auto pml2Entry = (virtualAddress & (cast(size_t)0x1FF << 21)) >> 21;
        auto pml1Entry = (virtualAddress & (cast(size_t)0x1FF << 12)) >> 12;

        // Find or create tables.
        size_t* pml3 = this.findOrAllocTable(this.pml4, pml4Entry);
        size_t* pml2 = this.findOrAllocTable(pml3, pml3Entry);
        size_t* pml1 = this.findOrAllocTable(pml2, pml2Entry);

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
        size_t* pml3 = this.findTable(this.pml4, pml4Entry);
        assert(pml3 != null);
        size_t* pml2 = this.findTable(pml3, pml3Entry);
        assert(pml2 != null);
        size_t* pml1 = this.findTable(pml2, pml2Entry);
        assert(pml1 != null);

        // Unmap.
        pml1[pml1Entry] = 0;

        // Cleanup.
        this.cleanTable(pml3);
        this.cleanTable(pml2);
        this.cleanTable(pml1);

        this.lock.release();
    }

    private void cleanTable(size_t* table) {
        for (size_t i = 0;; i++) {
            if (i == PT_ENTRIES) {
                freePage(cast(void*)(table) - MEM_PHYS_OFFSET);
            } else if (table[i] & PT_PRESENT) {
                return;
            }
        }
    }

    private size_t* findTable(size_t* parent, size_t index) {
        if (parent[index] & PT_PRESENT) {
            // Remove flags and take address.
            return cast(size_t*)((parent[index] & ~(0xFFF)) + MEM_PHYS_OFFSET);
        } else {
            return null;
        }
    }

    private size_t* findOrAllocTable(size_t* parent, size_t index) {
        auto ret = findTable(parent, index);

        if (ret == null) {
            ret = cast(size_t*)(allocPageAndZero() + MEM_PHYS_OFFSET);
            parent[index] = (cast(size_t)ret - MEM_PHYS_OFFSET) | 0b11;
        }

        return ret;
    }
}
