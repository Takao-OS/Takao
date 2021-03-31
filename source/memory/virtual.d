/// Virtual memory manager.
/// TODO: This is intentionally x86 specific since I dont know how
/// to do it in other archs or how to abstract details like PAT and others, this
/// will need to be heavily worked on for future porting to other archs.
module memory.virtual;

import lib.lock:       Lock;
import lib.panic:      panic;
import lib.alignment:  alignUp, alignDown;
import kernelprotocol: KernelMemoryMap, KernelMemoryEntry;
import main:           mainAllocator;

immutable pageSize = 0x1000; /// Size of a virtual page.

private immutable pageTablePresent = 1 << 0;
private immutable pageTableEntries = 512;

private size_t* findOrAllocPageTable(size_t* table, size_t index, size_t flags) {
    auto ret = findPageTable(table, index);

    if (ret == null) {
        ret = cast(size_t*)mainAllocator.allocAndZero(1);
        if (ret == null) {
            return null;
        }
        table[index] = cast(size_t)ret | flags;
    }

    return ret;
}

private size_t* findPageTable(size_t* table, size_t index) {
    if (table[index] & pageTablePresent) {
        // Remove flags and take address.
        return cast(size_t*)(table[index] & ~(cast(size_t)0xfff));
    } else {
        return null;
    }
}

private void cleanPageTable(size_t* table) {
    for (size_t i = 0;; i++) {
        if (i == pageTableEntries) {
            mainAllocator.free(cast(void*)table, 1);
        } else if (table[i] & pageTablePresent) {
            return;
        }
    }
}

/// Virtual address space.
struct VirtualSpace {
    private Lock    lock;
    private size_t* pml4;

    /// Create a virtual address space from a physical one.
    this(const ref KernelMemoryMap mmap) {
        pml4 = cast(size_t*)(mainAllocator.allocAndZero(1));
        if (pml4 == null) {
            panic("Could not allocate a pml4");
        }

        // If the hardware wants the 4GiB mapped so hard that it will triple fault
        // the fucking LAPIC and basically everything ever if I dont then it can
        // fucking have it.
        for (size_t i = 0; i < 0x100000000; i += pageSize) {
            mapPage(i, i, 0x03);
        }

        // Identity map the whole memory map.
        auto entries = mmap.entries[0..mmap.entryCount];
        import lib.debugtools: warn;
        foreach (ref entry; entries) {
            const alignedBase = alignDown(entry.base, pageSize);
            const newSize     = entry.size + (entry.base % pageSize);
            const alignedSize = alignUp(newSize, pageSize);

            for (ulong j = 0; j * pageSize < alignedSize; j++) {
                const addr = alignedBase + j * pageSize;
                // Skip over first 4 GiB
                if (addr < 0x100000000) {
                    continue;
                }
                mapPage(addr, addr, 0x03);
            }
        }
    }

    /// Set the mapping active for the current CPU.
    void setActive() {
        import arch.x86_64_stivale2.cpu: writeCR3;
        lock.acquire();
        writeCR3(cast(size_t)pml4);
        lock.release();
    }

    /// Map a physical address to a virtual one.
    void mapPage(size_t physicalAddress, size_t virtualAddress, size_t flags) {
        lock.acquire();

        // Calculate the indexes in the various tables using the virtual addr.
        auto pml4Entry = (virtualAddress & (cast(size_t)0x1ff << 39)) >> 39;
        auto pml3Entry = (virtualAddress & (cast(size_t)0x1ff << 30)) >> 30;
        auto pml2Entry = (virtualAddress & (cast(size_t)0x1ff << 21)) >> 21;
        auto pml1Entry = (virtualAddress & (cast(size_t)0x1ff << 12)) >> 12;

        // Find or create tables.
        size_t* pml3 = findOrAllocPageTable(pml4, pml4Entry, 0b111);
        if (pml3 == null) {
            panic("Could not find/allocate pml3");
        }
        size_t* pml2 = findOrAllocPageTable(pml3, pml3Entry, 0b111);
        if (pml2 == null) {
            panic("Could not find/allocate pml2");
        }
        size_t* pml1 = findOrAllocPageTable(pml2, pml2Entry, 0b111);
        if (pml1 == null) {
            panic("Could not find/allocate pml1");
        }

        // Set the entry as present and point it to the passed address.
        // Also set flags.
        pml1[pml1Entry] = physicalAddress | flags;

        lock.release();
    }

    /// Unmap a virtual address.
    void unmapPage(size_t virtualAddress) {
        lock.acquire();

        // Calculate the indexes in the various tables using the virtual addr.
        auto pml4Entry = (virtualAddress & (cast(size_t)0x1FF << 39)) >> 39;
        auto pml3Entry = (virtualAddress & (cast(size_t)0x1FF << 30)) >> 30;
        auto pml2Entry = (virtualAddress & (cast(size_t)0x1FF << 21)) >> 21;
        auto pml1Entry = (virtualAddress & (cast(size_t)0x1FF << 12)) >> 12;

        // Find or die if we dont find them.
        size_t* pml3 = findPageTable(pml4, pml4Entry);
        if (pml3 == null) {
            panic("Could not find pml3");
        }
        size_t* pml2 = findPageTable(pml3, pml3Entry);
        if (pml2 == null) {
            panic("Could not find pml2");
        }
        size_t* pml1 = findPageTable(pml2, pml2Entry);
        if (pml1 == null) {
            panic("Could not find pml1");
        }

        // Unmap.
        pml1[pml1Entry] = 0;

        // Cleanup.
        cleanPageTable(pml3);
        cleanPageTable(pml2);
        cleanPageTable(pml1);

        lock.release();
    }
}
