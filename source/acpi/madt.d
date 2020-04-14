module acpi.madt;

import acpi.lib;
import lib.messages;
import lib.alloc;
import lib.list;

struct MADT {
    align(1):
    SDTHeader header;
    uint      localControllerAddr;
    uint      flags;
    void*[]   madtEntriesBegin;
}

struct MADTheader {
    align(1):
    ubyte type;
    ubyte length;
}

struct MADTlocalApic {
    align(1):
    MADTheader header;
    ubyte      processorID;
    ubyte      apicID;
    uint       flags;
}

struct MADTioApic {
    align(1):
    MADTheader header;
    ubyte      apicID;
    ubyte      reserved;
    uint       addr;
    uint       gsib;
}

struct MADTiso {
    align(1):
    MADTheader header;
    ubyte      busSource;
    ubyte      irqSource;
    uint       gsi;
    ushort     flags;
}

struct MADTnmi {
    align(1):
    MADTheader header;
    ubyte      processor;
    ushort     flags;
    ubyte      lint;
}

private __gshared MADT*                  madt;
private __gshared List!(MADTlocalApic*)* madtLocalApics;
private __gshared List!(MADTioApic*)*    madtIoApics;
private __gshared List!(MADTiso*)*       madtISOs;
private __gshared List!(MADTnmi*)*       madtNMIs;

private __gshared bool madtInitialised = false;

struct MADTEntries {
    MADT*                  madt;
    List!(MADTlocalApic*)* localApics;
    List!(MADTioApic*)*    ioApics;
    List!(MADTiso*)*       ISOs;
    List!(MADTnmi*)*       NMIs;
}

MADTEntries getMADTEntries() {
    MADTEntries ret;

    if (!madtInitialised) {
        initMADT();
    }

    ret.madt       = madt;
    ret.localApics = madtLocalApics;
    ret.ioApics    = madtIoApics;
    ret.ISOs       = madtISOs;
    ret.NMIs       = madtNMIs;

    return ret;
}

private void initMADT() {
    madt = findSDT!MADT("APIC", 0);

    if (madt == null) {
        panic("No MADT found");
    }

    madtLocalApics = newObj!(List!(MADTlocalApic*))(16);
    madtIoApics    = newObj!(List!(MADTioApic*))(16);
    madtISOs       = newObj!(List!(MADTiso*))(16);
    madtNMIs       = newObj!(List!(MADTnmi*))(16);

    // parse the MADT entries
    for (auto madtPtr = cast(ubyte*)(&madt.madtEntriesBegin);
         cast(size_t)madtPtr < cast(size_t)madt + madt.header.length;
         madtPtr += *(madtPtr + 1)) {
        switch (*(madtPtr)) {
            case 0:
                log("acpi/madt: Found local APIC #", madtLocalApics.length);
                madtLocalApics.push(cast(MADTlocalApic*)madtPtr);
                break;
            case 1:
                log("acpi/madt: Found I/O APIC #", madtIoApics.length);
                madtIoApics.push(cast(MADTioApic*)madtPtr);
                break;
            case 2:
                log("acpi/madt: Found ISO #", madtISOs.length);
                madtISOs.push(cast(MADTiso*)madtPtr);
                break;
            case 4:
                log("acpi/madt: Found NMI #", madtNMIs.length);
                madtNMIs.push(cast(MADTnmi*)madtPtr);
                break;
            default:
                break;
        }
    }

    madtInitialised = true;
}
