module system.exceptions;

import system.cpu;
import lib.messages;

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

immutable EXC_DIV0 = 0x0;
immutable EXC_DEBUG = 0x1;
immutable EXC_NMI = 0x2;
immutable EXC_BREAKPOINT = 0x3;
immutable EXC_OVERFLOW = 0x4;
immutable EXC_BOUND = 0x5;
immutable EXC_INVOPCODE = 0x6;
immutable EXC_NODEV = 0x7;
immutable EXC_DBFAULT = 0x8;
immutable EXC_INVTSS = 0xa;
immutable EXC_NOSEGMENT = 0xb;
immutable EXC_SSFAULT = 0xc;
immutable EXC_GPF = 0xd;
immutable EXC_PAGEFAULT = 0xe;
immutable EXC_FP = 0x10;
immutable EXC_ALIGN = 0x11;
immutable EXC_MACHINECHK = 0x12;
immutable EXC_SIMD = 0x13;
immutable EXC_VIRT = 0x14;
immutable EXC_SECURITY = 0x1e;

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

extern (C) void exceptionHandler(int exception, Registers* regs, size_t errorCode) {
    panic("Fatal exception ", exceptionNames[exception], " (", exception,
        ") error code: ", errorCode, " RIP: ", regs.rip);
}
