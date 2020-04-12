module acpi.madt;

import acpi.lib;
import lib.messages;
import lib.alloc;

struct MADT {
    align(1):
    SDT     sdt;
    uint    localControllerAddr;
    uint    flags;
    void*[] madtEntriesBegin;
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

private __gshared MADT*           madt;
private __gshared MADTlocalApic** madtLocalApics;
private __gshared MADTioApic**    madtIoApics;
private __gshared MADTiso**       madtISOs;
private __gshared MADTnmi**       madtNMIs;

private __gshared bool madtInitialised = false;

struct MADTEntries {
    MADTlocalApic** localApics;
    MADTioApic**    ioApics;
    MADTiso**       ISOs;
    MADTnmi**       NMIs;
}

MADTEntries getMADTEntries() {
    MADTEntries ret;

    if (!madtInitialised) {
        initMADT();
    }

    ret.localApics = madtLocalApics;
    ret.ioApics    = madtIoApics;
    ret.ISOs       = madtISOs;
    ret.NMIs       = madtNMIs;

    return ret;
}

private void initMADT() {
    madt = findSDT!MADT("APIC", 0);

    // search for MADT table
    if (madt == null) {
        panic("No MADT found");
    }

    madtLocalApics = newArray!(MADTlocalApic*)();
    madtIoApics    = newArray!(MADTioApic*)();
    madtISOs       = newArray!(MADTiso*)();
    madtNMIs       = newArray!(MADTnmi*)();

    // parse the MADT entries
    for (ubyte *madtPtr = cast(ubyte*)(&madt.madtEntriesBegin);
         cast(size_t)madtPtr < cast(size_t)madt + madt.sdt.length;
         madtPtr += *(madtPtr + 1)) {
        switch (*(madtPtr)) {
            case 0: {
                size_t i = getArraySize(madtLocalApics);
                log("acpi/madt: Found local APIC #", i);
                resizeArray(&madtLocalApics, +1);
                madtLocalApics[i] = cast(MADTlocalApic*)madtPtr;
                break;
            }
            case 1: {
                size_t i = getArraySize(madtIoApics);
                log("acpi/madt: Found I/O APIC #", i);
                resizeArray(&madtIoApics, +1);
                madtIoApics[i] = cast(MADTioApic*)madtPtr;
                break;
            }
            case 2: {
                size_t i = getArraySize(madtISOs);
                log("acpi/madt: Found ISO #", i);
                resizeArray(&madtISOs, +1);
                madtISOs[i] = cast(MADTiso*)madtPtr;
                break;
            }
            case 4: {
                size_t i = getArraySize(madtNMIs);
                log("acpi/madt: Found NMI #", i);
                resizeArray(&madtNMIs, +1);
                madtNMIs[i] = cast(MADTnmi*)madtPtr;
                break;
            }
            default:
                break;
        }
    }

    madtInitialised = true;
}
