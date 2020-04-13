module system.smp;

import system.apic;
import lib.alloc;
import acpi.madt;
import lib.messages;
import system.cpu;
import memory.physical;
import system.pit;

__gshared size_t cpuCount = 1;

private immutable size_t cpuStackSize      = 32768;

extern extern (C) bool   smpCheckAPFlag();
extern extern (C) size_t smpPrepareTrampoline(void*  entryPoint,
                                              void*  stackPtr,
                                              size_t cpuNumber);

private void apEntryPoint(size_t cpuNumber) {
    log("smp: Started AP #", cpuNumber);
    for (;;) {
        asm {
            cli;
            hlt;
        }
    }
}

private int startAP(ubyte lapicID, size_t cpuNumber) {
    initCPULocal(cpuNumber, lapicID);

    auto stack      = newArray!ubyte(cpuStackSize);
    auto trampoline = smpPrepareTrampoline(&apEntryPoint, stack, cpuNumber);

    /* Send the INIT IPI */
    lapicWrite(0x310, cast(uint)lapicID << 24);
    lapicWrite(0x300, 0x500);
    /* wait 10ms */
    sleep(10);
    /* Send the Startup IPI */
    lapicWrite(0x310, cast(uint)lapicID << 24);
    lapicWrite(0x300, cast(uint)((trampoline / PAGE_SIZE) | 0x600));

    for (int i = 0; i < 1000; i++) {
        sleep(1);
        if (smpCheckAPFlag())
            return 0;
    }
    return -1;
}

void initSMP() {
    auto localApics = *(getMADTEntries().localApics);

    foreach (size_t i; 1..localApics.length) {
        uint flags = localApics[i].flags;
        if (!((flags & 1) ^ ((flags >> 1) & 1))) {
            continue;
        }

        log("smp: Starting up AP #", i);

        if (startAP(localApics[i].apicID, cpuCount)) {
            warn("smp: Failed to start AP #", i);
            continue;
        }

        cpuCount++;
    }

    log("smp: Total CPU count: ", cpuCount);
}
