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
    const mentries = &(memmap.entries);
    foreach (i; 0..memmap.count) {
        if (memmapCount >= privateMemmap.length) {
            break;
        }
        if (mentries[i].type != Stivale2MemoryType.Usable) {
            continue;
        }
        privateMemmap[memmapCount].base = mentries[i].base;
        privateMemmap[memmapCount].size = mentries[i].length;
        memmapCount++;
    }

    KernelMemoryMap ret;
    ret.entryCount = memmapCount;
    ret.entries    = cast(KernelMemoryEntry*)(privateMemmap.ptr);
    return ret;
}
