module cpu.intrinsics;

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

void writeCR3(size_t val) {
    asm {
        mov RAX, val;
        mov CR3, RAX;
    }
}

void outb(ushort port, ubyte val) {
    asm {
        mov DX, port;
        mov AL, val;
        out DX, AL;
    }
}

ubyte inb(ushort port) {
    ubyte val;

    asm {
        mov DX, port;
        in  AL, DX;
        mov val, AL;
    }

    return val;
}

void wait() {
    outb(0x80, 0);
}
