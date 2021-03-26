/// Functions for modifying and using the Global Descriptor Table.
module arch.x86_64_stivale2.gdt;

private align(1) struct GDTEntry {
    align(1):
    ushort limit;
    ushort baseLow16;
    ubyte  baseMid8;
    ubyte  access;
    ubyte  granularity;
    ubyte  baseHigh8;
}

private struct TSS {
    align(1):
    ushort length;
    ushort baseLow16;
    ubyte  baseMid8;
    ubyte  flags1;
    ubyte  flags2;
    ubyte  baseHigh8;
    uint   baseUpper32;
    uint   reserved;
}

private struct GDT {
    align(1):
    GDTEntry[5] entries;
    TSS         tss;
}

private struct GDTPointer {
    align(1):
    ushort size;
    GDT*   address;
}

immutable kernelCodeSegment = 0x08; /// Kernel code segment GDT index.
immutable kernelDataSegment = 0x10; /// Kernel data segment GDT index.
immutable tssSegment        = 0x28; /// TSS segment GDT index.

private shared GDT        gdt;
private shared GDTPointer gdtPointer;

/// Initialize the GDT structure and load it on the callee core.
void initGDT() {
    // Null descriptor.
    gdt.entries[0].limit       = 0;
    gdt.entries[0].baseLow16   = 0;
    gdt.entries[0].baseMid8    = 0;
    gdt.entries[0].access      = 0;
    gdt.entries[0].granularity = 0;
    gdt.entries[0].baseHigh8   = 0;

    // Kernel code.
    gdt.entries[1].limit       = 0;
    gdt.entries[1].baseLow16   = 0;
    gdt.entries[1].baseMid8    = 0;
    gdt.entries[1].access      = 0b10011010;
    gdt.entries[1].granularity = 0b00100000;
    gdt.entries[1].baseHigh8   = 0;

    // Kernel data.
    gdt.entries[2].limit       = 0;
    gdt.entries[2].baseLow16   = 0;
    gdt.entries[2].baseMid8    = 0;
    gdt.entries[2].access      = 0b10010010;
    gdt.entries[2].granularity = 0b00000000;
    gdt.entries[2].baseHigh8   = 0;

    // User data.
    gdt.entries[3].limit       = 0;
    gdt.entries[3].baseLow16   = 0;
    gdt.entries[3].baseMid8    = 0;
    gdt.entries[3].access      = 0b11110010;
    gdt.entries[3].granularity = 0;
    gdt.entries[3].baseHigh8   = 0;

    // User code.
    gdt.entries[4].limit       = 0;
    gdt.entries[4].baseLow16   = 0;
    gdt.entries[4].baseMid8    = 0;
    gdt.entries[4].access      = 0b11111010;
    gdt.entries[4].granularity = 0b00100000;
    gdt.entries[4].baseHigh8   = 0;

    // TSS.
    gdt.tss.length      = 104;
    gdt.tss.baseLow16   = 0;
    gdt.tss.baseMid8    = 0;
    gdt.tss.flags1      = 0b10001001;
    gdt.tss.flags2      = 0;
    gdt.tss.baseHigh8   = 0;
    gdt.tss.baseUpper32 = 0;
    gdt.tss.reserved    = 0;

    // Set GDT Pointer.
    gdtPointer.size    = gdt.sizeof - 1;
    gdtPointer.address = &gdt;

    // Load it on the current core.
    loadGDT();
}

/// Load the GDT to the current core, replacing segments and all.
void loadGDT() {
    asm {
        lgdt gdtPointer;

        // Long jump to set cs and ss.
        mov RBX, RSP;
        push kernelDataSegment;
        push RBX;
        pushfq;
        push kernelCodeSegment;
        lea RAX, [RIP + L1]; // Putting L1 directly dereferences L1 cause D dum dum.
        push RAX;
        iretq;

    L1:;
        mov AX, kernelDataSegment;
        mov DS, AX;
        mov ES, AX;
        mov FS, AX;
        mov GS, AX;
    }
}

/// Load an address on the active TSS.
/// Params:
///     address = Address to load on the TSS.
void loadTSS(size_t address) {
    gdt.tss.baseLow16   = cast(ushort)address;
    gdt.tss.baseMid8    = cast(ubyte)(address >> 16);
    gdt.tss.flags1      = 0b10001001;
    gdt.tss.flags2      = 0;
    gdt.tss.baseHigh8   = cast(ubyte)(address >> 24);
    gdt.tss.baseUpper32 = cast(uint)(address >> 32);
    gdt.tss.reserved    = 0;

    asm {
        // FIXME: https://github.com/ldc-developers/ldc/issues/3645
        push tssSegment;
        ltr [RSP];
        add RSP, 8;
    }
}
