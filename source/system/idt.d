/// Management of the IDT.
module system.idt;

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
    IDTDescriptor* address;
}

private shared IDTDescriptor[256] idtEntries;
private shared IDTPointer         idtPointer;

/// Initializes the global IDT and loads it for the callee core.
void initIDT() {
    import system.exceptions; // All of them really.

    // Fill up exceptions.
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

    // Fill up the ISRs.
    addInterrupt(0x20, &pitHandler, 0);

    // Load the IDT pointer.
    idtPointer.size    = idtEntries.sizeof - 1;
    idtPointer.address = idtEntries.ptr;
    loadIDT();
}

/// Load the global IDT in the callee core, which should be already initialized.
/// This function does not enable nor disable interrupts.
void loadIDT() {
    asm {
        lidt [idtPointer];
    }
}

private alias Handler = extern (C) void function();

private void addInterrupt(uint number, Handler handler, ubyte ist) {
    import system.gdt: kernelCodeSegment;

    const address = cast(size_t)handler;

    idtEntries[number].offsetLow    = cast(ushort)address;
    idtEntries[number].selector     = kernelCodeSegment;
    idtEntries[number].ist          = ist;
    idtEntries[number].flags        = 0x8E;
    idtEntries[number].offsetMiddle = cast(ushort)(address >> 16);
    idtEntries[number].offsetHigh   = cast(uint)(address >> 32);
    idtEntries[number].reserved     = 0;
}

    import scheduler.thread: reschedule;
    import system.pit:       tickHandler;
    import system.apic:      lapicEOI;

/// Handler of the PIT.
extern (C) void pitHandler() {
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

        call lapicEOI;
        call tickHandler;
        mov RDI, RSP;
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
