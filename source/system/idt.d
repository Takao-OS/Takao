module system.idt;

import system.gdt;
import system.pic;
import scheduler.thread;

private align(1) struct IDTDescriptor {
    align(1):
    ushort offsetLow;
    ushort selector;
    ubyte  ist;
    ubyte  flags;
    ushort offsetMiddle;
    uint   offsetHigh;
    uint   reserved;
}

struct IDTPointer {
    align(1):
    ushort size;
    void*  offset;
}

private __gshared IDTDescriptor[256] idtEntries;
private __gshared IDTPointer         idtPointer;

void initIDT() {
    asm {
        cli;
    }

    idtPointer = IDTPointer(idtEntries.sizeof - 1, cast(void*)&idtEntries);

    foreach (uint i; 0..idtEntries.length) {
        addInterrupt(i, &defaultInterruptHandler, 0);
    }

    addInterrupt(0x20, &pitHandler, 0);

    asm {
        lidt [idtPointer];
    }
}

private void addInterrupt(uint number, void function() handler, ubyte ist) {
    auto address = cast(size_t)handler;

    idtEntries[number].offsetLow    = cast(ushort)address;
    idtEntries[number].selector     = CODE_SEGMENT;
    idtEntries[number].ist          = ist;
    idtEntries[number].flags        = 0x8E;
    idtEntries[number].offsetMiddle = cast(ushort)(address >> 16);
    idtEntries[number].offsetHigh   = cast(uint)(address >> 32);
    idtEntries[number].reserved     = 0;
}

private void defaultInterruptHandler() {
    import lib.debugging;
    panic("Undefined interrupt!");
}

void pitHandler() {
    asm {
        naked;

        push RAX;
        push RBX;
        push RCX;
        push RDX;
        push RSI;
        push RDI;
        push RBP;
        push R8;
        push R9;
        push R10;
        push R11;
        push R12;
        push R13;
        push R14;
        push R15;

        mov RDI, RSP;
        mov DX, MASTERPIC_COMMAND;
        mov AL, PIC_EOI;
        out DX, AL;
        call reschedule;

        pop R15;
        pop R14;
        pop R13;
        pop R12;
        pop R11;
        pop R10;
        pop R9;
        pop R8;
        pop RBP;
        pop RDI;
        pop RSI;
        pop RDX;
        pop RCX;
        pop RBX;
        pop RAX;

        iretq;
    }
}
