/// Utilities for translating and manipulating memmaps.
module arch.x86_64_stivale2.memmap;

import arch.x86_64_stivale2.protocol: Stivale2Memmap, Stivale2MemoryType;
import kernelprotocol: KernelMemoryMap, KernelMemoryEntry;

// TODO: This being fixed could be an issue.
private shared KernelMemoryEntry[20] privateMemmap;

/// Translate a stivale2 memmap into a kernel one.
/// Params:
///     memmap = Pointer to memmap, never null.
/// Returns: The translated memmap.
KernelMemoryMap translateStivaleMemmap(Stivale2Memmap* memmap) {
    assert(memmap != null);

    size_t memmapCount;
    const mentries = (&memmap.entries)[0..memmap.count];
    foreach (entry; mentries) {
        if (memmapCount >= privateMemmap.length) {
            break;
        }
        privateMemmap[memmapCount].base   = entry.base;
        privateMemmap[memmapCount].size   = entry.length;
        privateMemmap[memmapCount].isFree = entry.type == Stivale2MemoryType.Usable ? true : false; 
        memmapCount++;
    }

    KernelMemoryMap ret;
    ret.entryCount = memmapCount;
    ret.entries    = cast(KernelMemoryEntry*)(privateMemmap.ptr);
    return ret;
}
