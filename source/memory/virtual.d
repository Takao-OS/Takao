/// Virtual memory manager, implementing wrappers around the arch specific ones.
module memory.virtual;

import lib.lock:       Lock;
import lib.panic:      panic;
import lib.alignment:  alignUp, alignDown;
import kernelprotocol: KernelMemoryEntry;
import archinterface:  ArchMMU, ArchMMUPage, ArchMappingType;

alias pageSize = ArchMMUPage;     /// Size of a virtual page.
alias MapType  = ArchMappingType; /// Types of maping.

/// Virtual address space.
struct VirtualSpace {
    private Lock    lock;
    private ArchMMU innerMMU;

    /// Create a virtual address space from a physical one.
    this(const KernelMemoryEntry[] memmap) {
        bool success; // @suppress(dscanner.suspicious.unmodified)
        innerMMU = ArchMMU(success);
        if (!success) {
            panic("Could not initialize the architecture MMU");
        }

        // If the hardware wants the 4GiB mapped so hard that it will triple fault
        // the fucking LAPIC and basically everything ever if I dont then it can
        // fucking have it.
        for (size_t i = 0; i < 0x100000000; i += pageSize) {
            innerMMU.mapPage(i, i, MapType.Supervisor);
        }

        // Identity map the whole memory map.
        foreach (ref entry; memmap) {
            const alignedBase = alignDown(entry.base, pageSize);
            const newSize     = entry.size + (entry.base % pageSize);
            const alignedSize = alignUp(newSize, pageSize);

            for (ulong j = 0; j * pageSize < alignedSize; j++) {
                const addr = alignedBase + j * pageSize;
                // Skip over first 4 GiB
                if (addr < 0x100000000) {
                    continue;
                }
                innerMMU.mapPage(addr, addr, MapType.Supervisor);
            }
        }
    }

    /// Set the mapping active for the current CPU.
    void setActive() {
        lock.acquire();
        innerMMU.setActive();
        lock.release();
    }

    /// Map a physical address to a virtual one.
    void mapPage(size_t physicalAddress, size_t virtualAddress, ubyte type) {
        lock.acquire();
        innerMMU.mapPage(physicalAddress, virtualAddress, type);
        lock.release();
    }

    /// Unmap a virtual address.
    void unmapPage(size_t virtualAddress) {
        lock.acquire();
        unmapPage(virtualAddress);
        lock.release();
    }
}
