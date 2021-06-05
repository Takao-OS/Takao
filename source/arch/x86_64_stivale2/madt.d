/// Parse and fetch information from the MADT.
module arch.x86_64_stivale2.madt;

import arch.x86_64_stivale2.acpi: SDTHeader, findSDT;
import lib.list:                  List;

/// MADT structure in memory.
struct MADT {
    align(1):
    SDTHeader header;       /// Common SDT header.
    uint      lapicAddress; /// Address of the LAPIC.
    uint      flags;        /// Flags of the table.
    void*     madtBegin;    /// Begin of the actual MADT.
}

/// Header of a MADT entry.
struct MADTHeader {
    align(1):
    ubyte type;   /// Type of the entry.
    ubyte length; /// Length of the entry.
}

/// Local APIC MADT entry.
struct MADTLAPIC {
    align(1):
    MADTHeader header;      /// Header of the entry.
    ubyte      processorID; /// ID of the processor.
    ubyte      lapicID;     /// LAPIC ID.
    uint       flags;       /// Flags of the entry.
}

/// IO-APIC MADT entry.
struct MADTIOAPIC {
    align(1):
    MADTHeader header;   /// Shared header of the entry.
    ubyte      apicID;   /// ID of the IOAPIC.
    ubyte      reserved; /// Reserved (???).
    uint       address;  /// Address of the IOAPIC.
    uint       gsib;     /// GSIB of the IOAPIC.
}

/// ISO MADT entry.
struct MADTISO {
    align(1):
    MADTHeader header;    /// Shared header of the entry.
    ubyte      busSource; /// Bus source.
    ubyte      irqSource; /// IRQ source.
    uint       gsi;       /// GSI of the ISO.
    ushort     flags;     /// Flags.
}

/// Non-maskable interrupt MADT entry.
struct MADTNMI {
    align(1):
    MADTHeader header;    /// Shared header of the entry.
    ubyte      processor; /// Processor ID.
    ushort     flags;     /// Flags.
    ubyte      lint;      /// Local interrupt index.
}

__gshared MADT*              madt;
__gshared List!(MADTLAPIC*)  madtLocalAPICs;
__gshared List!(MADTIOAPIC*) madtIOAPICs;
__gshared List!(MADTISO*)    madtISOs;
__gshared List!(MADTNMI*)    madtNMIs;

/// Fetch the MADT info and store it globally.
void initMADT() {
    import lib.panic:            panic;
    debug import lib.debugtools: log;

    madt = cast(MADT*)findSDT("APIC");
    if (madt == null) {
        panic("No MADT found");
    }

    madtLocalAPICs = List!(MADTLAPIC*)(16);
    madtIOAPICs    = List!(MADTIOAPIC*)(16);
    madtISOs       = List!(MADTISO*)(16);
    madtNMIs       = List!(MADTNMI*)(16);

    // parse the MADT entries
    for (auto madtPtr = cast(ubyte*)(&madt.madtBegin);
         cast(size_t)madtPtr < cast(size_t)madt + madt.header.length;
         madtPtr += *(madtPtr + 1)) {
        switch (*(madtPtr)) {
            case 0:
                debug log("acpi/madt: Found local APIC #", madtLocalAPICs.length);
                madtLocalAPICs.push(cast(MADTLAPIC*)madtPtr);
                break;
            case 1:
                debug log("acpi/madt: Found I/O APIC #", madtIOAPICs.length);
                madtIOAPICs.push(cast(MADTIOAPIC*)madtPtr);
                break;
            case 2:
                debug log("acpi/madt: Found ISO #", madtISOs.length);
                madtISOs.push(cast(MADTISO*)madtPtr);
                break;
            case 4:
                debug log("acpi/madt: Found NMI #", madtNMIs.length);
                madtNMIs.push(cast(MADTNMI*)madtPtr);
                break;
            default:
                break;
        }
    }
}
