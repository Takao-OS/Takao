module system.gdt;

private align(1) struct GDTEntry {
    align(1):
    ushort limit;
    ushort baseLow16;
    ubyte  baseMid8;
    ubyte  access;
    ubyte  granularity;
    ubyte  baseHigh8;
}

private struct GDTPointer {
    align(1):
    ushort size;
    void* address;
}

immutable CODE_SEGMENT = 0x08; // Second gdt entry.        
immutable DATA_SEGMENT = 0x10; // Third gdt entry.

private __gshared GDTEntry[3] gdtEntries;
private __gshared GDTPointer  gdtPointer;

void initGDT() {
    // Null descriptor.
    gdtEntries[0].limit       = 0;
    gdtEntries[0].baseLow16   = 0;
    gdtEntries[0].baseMid8    = 0;
    gdtEntries[0].access      = 0;
    gdtEntries[0].granularity = 0;
    gdtEntries[0].baseHigh8   = 0;

    // Kernel code.
    gdtEntries[1].limit       = 0;
    gdtEntries[1].baseLow16   = 0;
    gdtEntries[1].baseMid8    = 0;
    gdtEntries[1].access      = 0b10011010;
    gdtEntries[1].granularity = 0b00100000;
    gdtEntries[1].baseHigh8   = 0;

    // Kernel data.
    gdtEntries[2].limit       = 0;
    gdtEntries[2].baseLow16   = 0;
    gdtEntries[2].baseMid8    = 0;
    gdtEntries[2].access      = 0b10010010;
    gdtEntries[2].granularity = 0b00000000;
    gdtEntries[2].baseHigh8   = 0;

    // Set GDT Pointer.
    gdtPointer = GDTPointer(gdtEntries.sizeof - 1, cast(void*)&gdtEntries);

    // Set GDT.
    asm {
        lgdt [gdtPointer];

        // Long jump to set cs and ss.
        mov RBX, RSP;
        push DATA_SEGMENT;
        push RBX;
        pushfq;
        push CODE_SEGMENT;
        lea RAX, L1; // Putting L1 directly dereferences L1 cause D dum dum.
        push RAX;
        iretq;

    L1:;
        mov AX, DATA_SEGMENT;
        mov DS, AX;
        mov ES, AX;
        mov FS, AX;
        mov GS, AX;
    }
}
