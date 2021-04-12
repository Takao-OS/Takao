module arch.x86_64_stivale2.apic;

import arch.x86_64_stivale2.madt;
import core.volatile;
import arch.x86_64_stivale2.cpu;
import memory.alloc;

uint lapicRead(uint reg) {
    auto lapicBase = cast(size_t)madt.lapicAddress;
    return volatileLoad(cast(uint*)(lapicBase + reg));
}

void lapicWrite(uint reg, uint data) {
    auto lapicBase = cast(size_t)madt.lapicAddress;
    volatileStore(cast(uint*)(lapicBase + reg), data);
}

void lapicSetNMI(ubyte vec, ushort flags, ubyte lint) {
    uint nmi = 0x400 | vec;

    if (flags & 2) {
        nmi |= (1 << 13);
    }

    if (flags & 8) {
        nmi |= (1 << 15);
    }

    if (lint == 1) {
        lapicWrite(0x360, nmi);
    } else if (lint == 0) {
        lapicWrite(0x350, nmi);
    }
}

void lapicInstallNMI(ubyte vec, int nmi) {
    alias nmis = madtNMIs;
    lapicSetNMI(vec, nmis[nmi].flags, nmis[nmi].lint);
}

void lapicEnable() {
    lapicWrite(0xf0, lapicRead(0xf0) | 0x1ff);
}

void lapicEOI() {
    *lapicEOIptr = 0;
}

void lapicSendIPI(int cpu, ubyte vector) {
    lapicWrite(0x310, (cast(uint)cpuLocals[cpu].lapicID) << 24);
    lapicWrite(0x300, vector);
}

uint ioAPICRead(size_t ioAPIC, uint reg) {
    alias ioAPICs = madtIOAPICs;
    uint* base = cast(uint*)(cast(size_t)ioAPICs[ioAPIC].address);
    volatileStore(base, reg);
    return volatileLoad(base + 4);
}

void ioAPICWrite(size_t ioAPIC, uint reg, uint data) {
    alias ioAPICs = madtIOAPICs;
    auto  base    = cast(uint*)(cast(size_t)ioAPICs[ioAPIC].address);
    volatileStore(base,     reg);
    volatileStore(base + 4, data);
}


void ioAPICSetUpLegacyIRQ(int cpu, ubyte irq, bool status) {
    alias isos = madtISOs;

    foreach (size_t i; 0..isos.length) {
        if (isos[i].irqSource == irq) {
            ioAPICConnectGSIToVec(cpu, cast(ubyte)(isos[i].irqSource + 0x20),
                                  isos[i].gsi, isos[i].flags, status);
            return;
        }
    }

    ioAPICConnectGSIToVec(cpu, cast(ubyte)(irq + 0x20), cast(uint)irq,
                          cast(short)0, status);
}

uint ioAPICGetMaxRedirect(size_t ioAPIC) {
    return (ioAPICRead(ioAPIC, 1) & 0xff0000) >> 16;
}

size_t ioAPICFromGSI(uint gsi) {
    alias ioAPICs = madtIOAPICs;

    foreach (size_t i; 0..ioAPICs.length) {
        if (ioAPICs[i].gsib <= gsi && ioAPICs[i].gsib + ioAPICGetMaxRedirect(i) > gsi)
            return i;
    }

    return -1;
}

void ioAPICConnectGSIToVec(int cpu, ubyte vec, uint gsi, ushort flags, bool status) {
    alias ioAPICs = madtIOAPICs;
    auto  ioAPIC  = ioAPICFromGSI(gsi);

    long redirect = vec;

    // Active high(0) or low(1)
    if (flags & 2) {
        redirect |= (1 << 13);
    }

    // Edge(0) or level(1) triggered
    if (flags & 8) {
        redirect |= (1 << 15);
    }

    if (!status) {
        /* Set mask bit */
        redirect |= (1 << 16);
    }

    /* Set target APIC ID */
    redirect |= (cast(ulong)cpuLocals[cpu].lapicID) << 56;
    uint ioredtbl = (gsi - ioAPICs[ioAPIC].gsib) * 2 + 16;

    ioAPICWrite(ioAPIC, ioredtbl + 0, cast(uint)redirect);
    ioAPICWrite(ioAPIC, ioredtbl + 1, cast(uint)(redirect >> 32));
}

private __gshared uint* lapicEOIptr;

void initAPIC() {
    debug import lib.debugtools: log;
    auto lapicBase = cast(size_t)madt.lapicAddress;
    lapicEOIptr = cast(uint*)(lapicBase + 0xb0);
    lapicEnable();
    debug log("apic: Done! APIC initialised.");
}
