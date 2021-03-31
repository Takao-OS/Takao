/// Functions and structures to abstract ports.
module archinterface;

debug {
    /// Output a character to an architecture specific debug output.
    /// Params:
    ///     c = Char to print.
    void debugPrintChar(char c) {
        import arch.x86_64_stivale2.cpu: outb;
        outb(0xe9, c);
    }
}

/// Enables interruptions for the current core.
void enableInterrupts() {
    asm { naked; sti; ret; }
}

/// Disables interruptions for the current core.
void disableInterrupts() {
    asm { naked; cli; ret; }
}

/// Makes a core sleep by at least the passed ammount of miliseconds.
/// Params:
///     msecs = Miliseconds to sleep.
void sleep(size_t msec) {
    import arch.x86_64_stivale2.pit: pitsleep = sleep;
    pitsleep(msec);
}

/// Registers a function as an interrupt for all CPUs.
/// Params:
///     num = Number of interrupt to use, if possible, size_t.max for up to the
///           function to decide.
///     func = Function to use for the interrupt, not null.
/// Returns: The allocated interrupt number, or size_t.max in failure.
size_t registerGlobalInterrupt(size_t num, void function() func) {
    import arch.x86_64_stivale2.idt: addInterrupt, Handler;

    assert(func != null);

    if (num != size_t.max) {
        addInterrupt(cast(uint)num, cast(Handler)func, false);
        return num;
    } else {
        // TODO: Support arbitrary interrupt allocation.
        return size_t.max;
    }
}

/// Enables or disables an interrupt reception in the current CPU.
/// Params:
///     num    = Number of interrupt to modify.
///     enable = True to enable, false to disable.
void maskCoreInterrupt(size_t num, bool enable) {
    import arch.x86_64_stivale2.apic: ioAPICSetUpLegacyIRQ;
    ioAPICSetUpLegacyIRQ(cast(int)getCurrentCore(), cast(ubyte)num, enable);
}

/// Get core count of the system, including the current core.
/// Returns: At least 1 (for obvious reasons).
size_t getCoreCount() {
    import arch.x86_64_stivale2.smp: cpuCount;
    return cpuCount;
}

/// Get current core number.
/// Returns: 0-based core number.
size_t getCurrentCore() {
    import arch.x86_64_stivale2.cpu: currentCPU;
    return currentCPU();
}

/// Drive the current core into an unrecoverable state.
void killCore() {
    asm {
        naked;
    L1:
        cli;
        hlt;
        jmp L1;
    }
}

/// Make the passed core execute code starting from the passed function.
/// Any kind of state is not to be assumed preserved, and its not safe to let
/// the core return from the function.
/// Params:
///     core = Core to override execution from.
///     func = Function to execute, not null.
void executeCore(size_t core, void function() func) {
    import arch.x86_64_stivale2.apic: lapicSendIPI;
    import arch.x86_64_stivale2.cpu:  cpuLocals;

    assert(func != null);

    cpuLocals[core].execLock.acquire();
    cpuLocals[core].exec = func;
    cpuLocals[core].execLock.release();
    lapicSendIPI(cast(int)core, 0xcc);
}

private immutable pageSize         = 0x1000;
private immutable pageTablePresent = 1 << 0;
private immutable pageTableEntries = 512;

import main: mainAllocator;

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

/// Types of mapping the MMU can do.
enum ArchMappingType : ubyte {
    Supervisor   = 0b00000001, /// Page owned by the kernel, else by the user.
    ReadOnly     = 0b00000010, /// Read only for the owner, else can also write.
    NoExecute    = 0b00000100, /// Cannot execute page, else can execute.
    Global       = 0b00001000, /// Page is global, else is local.
    WriteCombine = 0b00010000  /// Page is write combining, else its not.
}

immutable ArchMMUPage = 0x1000; /// Size of the MMU page, and alignment for mappings.

/// MMU of a given core for a given arch, not locked.
struct ArchMMU {
    private size_t* pml4;

    /// Create a core specific MMU.
    this(out bool success) {
        pml4    = cast(size_t*)(mainAllocator.allocAndZero(1));
        success = pml4 == null ? false : true;
    }

    void setActive() {
        import arch.x86_64_stivale2.cpu: writeCR3;
        writeCR3(cast(size_t)pml4);
    }

    /// Map a physical 4k block of addresses to a virtual one.
    /// Returns: true if success, false if failure.
    bool mapPage(size_t physicalAddress, size_t virtualAddress, ubyte type) {
        // Calculate the indexes in the various tables using the virtual addr.
        auto pml4Entry = (virtualAddress & (cast(size_t)0x1ff << 39)) >> 39;
        auto pml3Entry = (virtualAddress & (cast(size_t)0x1ff << 30)) >> 30;
        auto pml2Entry = (virtualAddress & (cast(size_t)0x1ff << 21)) >> 21;
        auto pml1Entry = (virtualAddress & (cast(size_t)0x1ff << 12)) >> 12;

        // Find or create tables.
        size_t* pml3 = findOrAllocPageTable(pml4, pml4Entry, 0b111);
        if (pml3 == null) {
            return false;
        }
        size_t* pml2 = findOrAllocPageTable(pml3, pml3Entry, 0b111);
        if (pml2 == null) {
            return false;
        }
        size_t* pml1 = findOrAllocPageTable(pml2, pml2Entry, 0b111);
        if (pml1 == null) {
            return false;
        }

        // Set the entry as present and point it to the passed address.
        // Also set flags.
        ulong flags;
        if (!(type & ArchMappingType.Supervisor)) {
            flags |= (1 << 2);
        }
        if (!(type & ArchMappingType.ReadOnly)) {
            flags |= (1 << 1);
        }
        if (type & ArchMappingType.Global) {
            flags |= (1 << 8);
        }
        if (type & ArchMappingType.WriteCombine) {
            flags |= (1 << 7);
        }
        pml1[pml1Entry] = physicalAddress | flags | 1;
        asm {
            invlpg virtualAddress;
        }
        return true;
    }

    /// Unmap a 4k virtual address block.
    /// Returns: true if success, false if failure.
    bool unmapPage(size_t virtualAddress) {
        // Calculate the indexes in the various tables using the virtual addr.
        auto pml4Entry = (virtualAddress & (cast(size_t)0x1FF << 39)) >> 39;
        auto pml3Entry = (virtualAddress & (cast(size_t)0x1FF << 30)) >> 30;
        auto pml2Entry = (virtualAddress & (cast(size_t)0x1FF << 21)) >> 21;
        auto pml1Entry = (virtualAddress & (cast(size_t)0x1FF << 12)) >> 12;

        // Find or die if we dont find them.
        size_t* pml3 = findPageTable(pml4, pml4Entry);
        if (pml3 == null) {
            return false;
        }
        size_t* pml2 = findPageTable(pml3, pml3Entry);
        if (pml2 == null) {
            return false;
        }
        size_t* pml1 = findPageTable(pml2, pml2Entry);
        if (pml1 == null) {
            return false;
        }

        // Unmap.
        pml1[pml1Entry] = 0;

        // Cleanup.
        cleanPageTable(pml3);
        cleanPageTable(pml2);
        cleanPageTable(pml1);
        asm {
            invlpg virtualAddress;
        }
        return true;
    }
}
