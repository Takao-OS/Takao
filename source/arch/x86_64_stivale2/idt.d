module arch.x86_64_stivale2.idt;

import arch.x86_64_stivale2.gdt;
import arch.x86_64_stivale2.cpu;
import arch.x86_64_stivale2.exceptions;
import arch.x86_64_stivale2.apic;
import arch.x86_64_stivale2.pit;
import arch.x86_64_stivale2.ps2keyboard: keyboardHandler;
import arch.x86_64_stivale2.ps2mouse:    mouseHandler;

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

private struct IDTPointer {
    align(1):
    ushort         size;
    IDTDescriptor* offset;
}

alias Handler = extern (C) void function();

private __gshared IDTDescriptor[256] idtEntries;
private __gshared IDTPointer         idtPointer;

/// Load the IDT.
void initIDT() {
    asm {
        cli;
    }

    idtPointer = IDTPointer(idtEntries.sizeof - 1, idtEntries.ptr);

    addInterrupt(0x00, &excDiv0Handler, 0);
    addInterrupt(0x01, &excDebugHandler, 0);
    addInterrupt(0x02, &excNmiHandler, 0);
    addInterrupt(0x03, &excBreakpointHandler, 0);
    addInterrupt(0x04, &excOverflowHandler, 0);
    addInterrupt(0x05, &excBoundRangeHandler, 0);
    addInterrupt(0x06, &excInvOpcodeHandler, 0);
    addInterrupt(0x07, &excNoDevHandler, 0);
    addInterrupt(0x08, &excDoubleFaultHandler, 0);
    addInterrupt(0x0a, &excInvTssHandler, 0);
    addInterrupt(0x0b, &excNoSegmentHandler, 0);
    addInterrupt(0x0c, &excSsFaultHandler, 0);
    addInterrupt(0x0d, &excGpfHandler, 0);
    addInterrupt(0x0e, &excPageFaultHandler, 0);
    addInterrupt(0x10, &excX87FpHandler, 0);
    addInterrupt(0x11, &excAlignmentCheckHandler, 0);
    addInterrupt(0x12, &excMachineCheckHandler, 0);
    addInterrupt(0x13, &excSimdFpHandler, 0);
    addInterrupt(0x14, &excVirtHandler, 0);
    addInterrupt(0x1e, &excSecurityHandler, 0);

    addInterrupt(0x20, &pitHandler,         0);
    addInterrupt(0x21, &ps2keyboardHandler, 0);
    addInterrupt(0x2c, &ps2MouseHandler,    0);

    addInterrupt(0xcc, &kernelExecutionHandler, 0);

    loadIDT();
}

void loadIDT() {
    asm {
        lidt [idtPointer];
    }
}

void addInterrupt(uint number, Handler handler, ubyte ist) {
    auto address = cast(size_t)handler;

    idtEntries[number].offsetLow    = cast(ushort)address;
    idtEntries[number].selector     = kernelCodeSegment;
    idtEntries[number].ist          = ist;
    idtEntries[number].flags        = 0x8E;
    idtEntries[number].offsetMiddle = cast(ushort)(address >> 16);
    idtEntries[number].offsetHigh   = cast(uint)(address >> 32);
    idtEntries[number].reserved     = 0;
}

private extern (C) void pitHandler() {
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

        call tickHandler;
        call lapicEOI;

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

private extern (C) void ps2keyboardHandler() {
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

        call keyboardHandler;
        call lapicEOI;

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

private extern (C) void ps2MouseHandler() {
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

        call mouseHandler;
        call lapicEOI;

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


private extern (C) void kernelExecutionHandler() {
    asm {
        naked;
        cld;
        call lapicEOI;
        sti;
        call execSwitcher;
    }
}

private void execSwitcher() {
    cpuLocals[currentCPU()].execLock.acquire();
    auto exec = cpuLocals[currentCPU()].exec;
    cpuLocals[currentCPU()].execLock.release();
    exec();
}
