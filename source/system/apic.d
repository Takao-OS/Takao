module system.apic;

import memory.virtual;
import lib.messages;
import acpi.madt;
import core.volatile;
import system.cpu;
import lib.alloc;

uint lapicRead(uint reg) {
    auto madt = getMADTEntries();
    size_t lapicBase = cast(size_t)madt.madt.localControllerAddr + MEM_PHYS_OFFSET;
    return volatileLoad(cast(uint*)(lapicBase + reg));
}

void lapicWrite(uint reg, uint data) {
    auto madt = getMADTEntries();
    size_t lapicBase = cast(size_t)madt.madt.localControllerAddr + MEM_PHYS_OFFSET;
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
    auto madt = getMADTEntries();
    lapicSetNMI(vec, madt.NMIs[nmi].flags, madt.NMIs[nmi].lint);
}

void lapicEnable() {
    lapicWrite(0xf0, lapicRead(0xf0) | 0x1ff);
}

void lapicEOI() {
    lapicWrite(0xb0, 0);
}

void lapicSendIPI(int cpu, ubyte vector) {
    lapicWrite(0x300, (cast(uint)cpuLocals[cpu].lapicID) << 24);
    lapicWrite(0x310, vector);
}

uint ioAPICRead(size_t ioAPIC, uint reg) {
    auto madt = getMADTEntries();
    uint* base = cast(uint*)(cast(size_t)madt.ioApics[ioAPIC].addr + MEM_PHYS_OFFSET);
    volatileStore(base, reg);
    return volatileLoad(base + 4);
}

void ioAPICWrite(size_t ioAPIC, uint reg, uint data) {
    auto madt = getMADTEntries();
    auto base = cast(uint*)(cast(size_t)madt.ioApics[ioAPIC].addr + MEM_PHYS_OFFSET);
    volatileStore(base,     reg);
    volatileStore(base + 4, data);
}


void ioAPICSetUpLegacyIRQ(int cpu, ubyte irq, bool status) {
    auto madt = getMADTEntries();
    foreach (size_t i; 0..getArraySize(madt.ISOs)) {
        if (madt.ISOs[i].irqSource == irq) {
            ioAPICConnectGSIToVec(cpu, cast(ubyte)(madt.ISOs[i].irqSource + 0x20),
                                  madt.ISOs[i].gsi, madt.ISOs[i].flags, status);
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
    auto madt = getMADTEntries();
    foreach (size_t i; 0..getArraySize(madt.ioApics)) {
        if (madt.ioApics[i].gsib <= gsi && madt.ioApics[i].gsib + ioAPICGetMaxRedirect(i) > gsi)
            return i;
    }

    return -1;
}

void ioAPICConnectGSIToVec(int cpu, ubyte vec, uint gsi, ushort flags, bool status) {
    auto madt = getMADTEntries();
    size_t ioAPIC = ioAPICFromGSI(gsi);

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
    uint ioredtbl = (gsi - madt.ioApics[ioAPIC].gsib) * 2 + 16;

    ioAPICWrite(ioAPIC, ioredtbl + 0, cast(uint)redirect);
    ioAPICWrite(ioAPIC, ioredtbl + 1, cast(uint)(redirect >> 32));
}

void initAPIC() {
    auto madt = getMADTEntries();
    size_t lapicBase = cast(size_t)madt.madt.localControllerAddr + MEM_PHYS_OFFSET;
    log("apic: Done! APIC initialised.");
}
