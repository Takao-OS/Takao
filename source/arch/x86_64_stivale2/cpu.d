module arch.x86_64_stivale2.cpu;

import memory.alloc: allocate, getAllocationSize, resizeAllocationAbs;
import lib.lock:     Lock;

align(16) struct TSS {
    align(1):
    uint  unused0;
    ulong rsp0;
    ulong rsp1;
    ulong rsp2;
    ulong unused1;
    ulong ist1;
    ulong ist2;
    ulong ist3;
    ulong ist4;
    ulong ist5;
    ulong ist6;
    ulong ist7;
    ulong unused2;
    uint  iopbOffset;
}

struct CPULocal {
    align(1):
    uint cpuNumber;
    byte lapicID;
    int  currentThread;
    Lock execLock;
    void function() exec;
}

private __gshared Lock coreLock;
__gshared size_t    cpuCount;
__gshared CPULocal* cpuLocals;

extern(C) size_t currentCPU() {
    asm {
        naked;
        mov EAX, [GS:0];
        ret;
    }
}

void initCPULocals(size_t cpus) {
    cpuCount  = cpus;
    cpuLocals = allocate!CPULocal(cpus);
}

void initCPU(uint core, byte lapicID) {
    import arch.x86_64_stivale2.apic: lapicEnable;

    coreLock.acquire();
    cpuLocals[core].cpuNumber     = core;
    cpuLocals[core].lapicID       = lapicID;
    cpuLocals[core].currentThread = -1;
    cpuLocals[core].execLock.release();
    lapicEnable();

    // Set gsbase.
    writeMSR(0xc0000101, cast(ulong)&cpuLocals[core]);

    // Enable SSE without checking because this is x86_64
    ulong cr0 = readCR0();
    cr0 &= ~(1 << 2);
    cr0 |=  (1 << 1);
    writeCR0(cr0);

    // Enable write-combining in the PAT.
    ulong pat = readMSR(0x277);
    pat &= 0xffffffff;
    pat |= cast(ulong)0x0105 << 32; // write-protect / write-combining
    writeMSR(0x277, pat);

    coreLock.release();
}

struct Registers {
    size_t r15;
    size_t r14;
    size_t r13;
    size_t r12;
    size_t r11;
    size_t r10;
    size_t r9;
    size_t r8;
    size_t rbp;
    size_t rdi;
    size_t rsi;
    size_t rdx;
    size_t rcx;
    size_t rbx;
    size_t rax;
    size_t rip;
    size_t cs;
    size_t rflags;
    size_t rsp;
    size_t ss;
}

extern (C) void writeMSR(ulong msr, ulong val) {
    asm {
        naked;
        mov RAX, RSI;
        mov RDX, RSI;
        shr RDX, 32;
        mov RCX, RDI;
        wrmsr;
        ret;
    }
}

extern (C) ulong readMSR(ulong msr) {
    asm {
        naked;
        xor EAX, EAX;
        mov RCX, RDI;
        rdmsr;
        shl RDX, 32;
        or  RAX, RDX;
        ret;
    }
}

extern (C) ulong readCR0() {
    asm {
        naked;
        mov RAX, CR0;
        ret;
    }
}

extern (C) void writeCR0(ulong val) {
    asm {
        naked;
        mov CR0, RDI;
        ret;
    }
}

extern (C) ulong readCR3() {
    asm {
        naked;
        mov RAX, CR3;
        ret;
    }
}

extern (C) void writeCR3(ulong val) {
    asm {
        naked;
        mov CR3, RDI;
        ret;
    }
}

extern (C) ulong invlpg(size_t virtualAddress) {
    asm {
        naked;
        invlpg [RDI];
        ret;
    }
}

extern (C) void outb(ushort port, ubyte val) {
    asm {
        naked;
        mov DX, DI;
        mov AX, SI;
        out DX, AL;
        ret;
    }
}

extern (C) ubyte inb(ushort port) {
    asm {
        naked;
        xor EAX, EAX;
        mov DX,  DI;
        in  AL,  DX;
        ret;
    }
}

extern (C) void outw(ushort port, ushort val) {
    asm {
        naked;
        mov DX, DI;
        mov AX, SI;
        out DX, AX;
        ret;
    }
}

extern (C) ushort inw(ushort port) {
    asm {
        naked;
        xor EAX, EAX;
        mov DX,  DI;
        in  AX,  DX;
        ret;
    }
}

extern (C) void outd(ushort port, uint val) {
    asm {
        naked;
        mov DX, DI;
        mov EAX, ESI;
        out DX, EAX;
        ret;
    }
}

extern (C) uint ind(ushort port) {
    asm {
        naked;
        xor EAX, EAX;
        mov DX,  DI;
        in  EAX,  DX;
        ret;
    }
}
