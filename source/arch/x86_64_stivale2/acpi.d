/// ACPI table parsing and analysis.
module arch.x86_64_stivale2.acpi;

debug import lib.debugtools: log, warn;

private struct RSDP {
    align(1):
    char[8]  signature;
    ubyte    checksum;
    char[6]  oemID;
    ubyte    rev;
    uint     rsdtAddr;
    // ver 2.0 only
    uint     length;
    ulong    xsdtAddr;
    ubyte    extChecksum;
    ubyte[3] reserved;
}

private struct SDT {
    align(1):
    SDTHeader header;
    void*     sdtPtr;
}

/// Header of an SDT table.
struct SDTHeader {
    align(1):
    char[4] signature;  /// Signature of the table.
    uint    length;     /// Length of the table.
    ubyte   rev;        /// Revision.
    ubyte   checksum;   /// Checksum.
    char[6] oemID;      /// OEM ID.
    char[8] oemTableID; /// OEM table ID.
    uint    oemRev;     /// OEM revision.
    uint    creatorID;  /// Creator ID.
    uint    creatorRev; /// Creator revision.
}

private shared bool isXSDT;
private shared SDT* sdt;

/// Initialize ACPI global state.
/// Params:
///     rsdpAddress = Physical address of the RSDP to use.
void initACPI(size_t rsdpAddress) {
    const rsdp = cast(RSDP*)rsdpAddress;

    if (rsdp.rev >= 2 && rsdp.xsdtAddr) {
        isXSDT = true;
        sdt    = cast(shared SDT*)(cast(void*)rsdp.xsdtAddr);
        debug log("acpi: Using XSDT at ", cast(void*)sdt);
    } else {
        isXSDT = false;
        sdt    = cast(shared SDT*)(cast(void*)rsdp.rsdtAddr);
        debug log("acpi: Using RSDT at ", cast(void*)sdt);
    }
}

/// Find an SDT using the present ACPI tables.
/// Params:
///     signature = Signature of the table to search.
/// Returns: Address of the table or null if not found.
void* findSDT(char[4] signature) {
    debug import lib.string: fromCString;

    const size_t limit = (sdt.header.length - sdt.header.sizeof) / (isXSDT ? 8 : 4);

    SDTHeader* ptr;
    foreach (i; 0..limit) {
        if (isXSDT) {
            auto p = cast(ulong*)(&sdt.sdtPtr);
            ptr = cast(SDTHeader*)p[i];
        } else {
            auto p = cast(uint*)(&sdt.sdtPtr);
            ptr = cast(SDTHeader*)p[i];
        }

        if (ptr.signature == signature) {
            return cast(void*)ptr;
        }
    }

    debug warn("acpi: Did not find '", fromCString(signature.ptr, 4), "'");
    return null;
}
