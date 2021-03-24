/// CPU exceptions.
module arch.x86_64_stivale2.exceptions;

import arch.x86_64_stivale2.cpu: Registers;

/// Handlers.
extern extern (C) void excDiv0Handler();
extern extern (C) void excDebugHandler();
extern extern (C) void excNmiHandler();
extern extern (C) void excBreakpointHandler();
extern extern (C) void excOverflowHandler();
extern extern (C) void excBoundRangeHandler();
extern extern (C) void excInvOpcodeHandler();
extern extern (C) void excNoDevHandler();
extern extern (C) void excDoubleFaultHandler();
extern extern (C) void excInvTssHandler();
extern extern (C) void excNoSegmentHandler();
extern extern (C) void excSsFaultHandler();
extern extern (C) void excGpfHandler();
extern extern (C) void excPageFaultHandler();
extern extern (C) void excX87FpHandler();
extern extern (C) void excAlignmentCheckHandler();
extern extern (C) void excMachineCheckHandler();
extern extern (C) void excSimdFpHandler();
extern extern (C) void excVirtHandler();
extern extern (C) void excSecurityHandler();

private immutable EXC_DIV0 = 0x0;
private immutable EXC_DEBUG = 0x1;
private immutable EXC_NMI = 0x2;
private immutable EXC_BREAKPOINT = 0x3;
private immutable EXC_OVERFLOW = 0x4;
private immutable EXC_BOUND = 0x5;
private immutable EXC_INVOPCODE = 0x6;
private immutable EXC_NODEV = 0x7;
private immutable EXC_DBFAULT = 0x8;
private immutable EXC_INVTSS = 0xa;
private immutable EXC_NOSEGMENT = 0xb;
private immutable EXC_SSFAULT = 0xc;
private immutable EXC_GPF = 0xd;
private immutable EXC_PAGEFAULT = 0xe;
private immutable EXC_FP = 0x10;
private immutable EXC_ALIGN = 0x11;
private immutable EXC_MACHINECHK = 0x12;
private immutable EXC_SIMD = 0x13;
private immutable EXC_VIRT = 0x14;
private immutable EXC_SECURITY = 0x1e;

private __gshared string[] exceptionNames = [
    "Division by 0",
    "Debug",
    "NMI",
    "Breakpoint",
    "Overflow",
    "Bound range exceeded",
    "Invalid opcode",
    "Device not available",
    "Double fault",
    "???",
    "Invalid TSS",
    "Segment not present",
    "Stack-segment fault",
    "General protection fault",
    "Page fault",
    "???",
    "x87 exception",
    "Alignment check",
    "Machine check",
    "SIMD exception",
    "Virtualisation",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "Security"
];

/// Exception handler called from ASM.
extern (C) void exceptionHandler(int exception, Registers* regs, size_t errorCode) {
    import lib.panic: panic;
    const name = exceptionNames[exception];
    panic(name, " (", exception, ") error code: ", errorCode, " RIP: ", regs.rip);
}
