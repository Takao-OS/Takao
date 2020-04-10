module virt.ept;

import memory.physical;
import memory.virtual;
import lib.lock;

private immutable ulong EPT_READ = 0;
private immutable ulong EPT_WRITE = 1;
private immutable ulong EPT_EXEC = 2;
private immutable ulong EPT_USEREXEC = 10;
private immutable ulong EPT_PHYSADDR = 12;
private immutable ulong EPT_IGNORE_PAT = 6;
private immutable ulong EPT_MEMORY_TYPE = 3;

struct EptAddressSpace {
    private Lock    lock;
    private size_t* pml4e;

    this(size_t* pml4e) {
        this.pml4e = pml4e;
    }

    void eptMapPage(size_t guestAddress, size_t hostAddress, size_t flags) {
        this.lock.acquire();
        int pml4eIdx = (((guestAddress) >> 39) & 0x1ff);
        int pdpteIdx = (((guestAddress) >> 30) & 0x1ff);
        int pdeIdx   = (((guestAddress) >> 21) & 0x1ff);
        int pteIdx   = (((guestAddress) >> 12) & 0x1ff);

        size_t* pml3e = findOrAllocPageTable(this.pml4e, pml4eIdx, EPT_READ);
        size_t* pml2e = findOrAllocPageTable(pml3e, pdpteIdx, EPT_READ);
        size_t* pml1e = findOrAllocPageTable(pml2e, pdeIdx, EPT_READ);

        pml1e[pteIdx] = hostAddress | flags;
        this.lock.release();
    }

    void unmapPage(size_t guestAddress) {
        this.lock.acquire();

        // Calculate the indexes in the various tables using the virtual addr.
        auto pml4Entry = (guestAddress & (cast(size_t)0x1FF << 39)) >> 39;
        auto pml3Entry = (guestAddress & (cast(size_t)0x1FF << 30)) >> 30;
        auto pml2Entry = (guestAddress & (cast(size_t)0x1FF << 21)) >> 21;
        auto pml1Entry = (guestAddress & (cast(size_t)0x1FF << 12)) >> 12;

        // Find or die if we dont find them.
        size_t* pml3 = findPageTable(this.pml4e, pml4Entry);
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

        this.lock.release();
    }
}
