module acpi.lib;

import lib.string;
import lib.messages;
import lib.glue;
import memory.virtual;

struct RSDP {
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

struct SDT {
    align(1):
    char[4] signature;
    uint    length;
    ubyte   rev;
    ubyte   checksum;
    char[6] oemID;
    char[8] oemTableID;
    uint    oemRev;
    uint    creatorID;
    uint    creatorRev;
    void*[] sdtPtr;
}

private __gshared bool useXSDT;
private __gshared SDT* sdt;

void initACPI(RSDP* rsdp) {
    log("acpi: RSDP at ", cast(size_t)rsdp, ", ACPI revision ", rsdp.rev);

    if (rsdp.rev >= 2 && rsdp.xsdtAddr) {
        useXSDT = true;
        sdt = cast(SDT*)(cast(void*)rsdp.xsdtAddr + MEM_PHYS_OFFSET);
        log("acpi: Using XSDT at ", cast(size_t)sdt);
    } else {
        useXSDT = false;
        sdt = cast(SDT*)(cast(void*)rsdp.rsdtAddr + MEM_PHYS_OFFSET);
        log("acpi: Using RSDT at ", cast(size_t)sdt);
    }
}

T* findSDT(T)(string signature, int index) {
    SDT* ptr;
    int  count = 0;

    size_t limit = (sdt.length - SDT.sizeof) / (useXSDT ? 8 : 4);

    for (size_t i = 0; i < limit; i++) {
        if (useXSDT) {
            auto p = cast(ulong*)(&sdt.sdtPtr);
            ptr = cast(SDT*)((cast(void*)p[i]) + MEM_PHYS_OFFSET);
        } else {
            auto p = cast(uint*)(&sdt.sdtPtr);
            ptr = cast(SDT*)((cast(void*)p[i]) + MEM_PHYS_OFFSET);
        }

        if (fromCString(cast(char*)ptr.signature, 4) == signature) {
            if (count++ == index) {
                log("acpi: Found '", signature, "' at ", cast(size_t)ptr);
                return cast(T*)ptr;
            }
        }
    }

    log("acpi: Did not find '", signature, "'");
    return null;
}
