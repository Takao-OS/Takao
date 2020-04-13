section .text

%define HIGHER_HALF_OFFSET 0xffff800000000000
%define TRAMPOLINE_ADDR    0x1000

%define CPU_STARTED_FLAG 0x2000
%define ENTRY_POINT_ADDR 0x2008
%define PAGEMAP_PTR      0x2010
%define STACK_PTR        0x2018
%define CPU_NUMBER       0x2020
%define GDT_PTR_LOWER    0x2030
%define GDT_PTR          0x2040
%define IDT_PTR          0x2050

global smpCheckAPFlag
smpCheckAPFlag:
    xor  eax, eax
    mov  rcx, CPU_STARTED_FLAG + HIGHER_HALF_OFFSET
    lock xchg [rcx], rax
    ret

global smpPrepareTrampoline
smpPrepareTrampoline: ; (entryPoint, stackPtr, cpuNumber)
    xor  rax, rax
    mov  rcx, CPU_STARTED_FLAG + HIGHER_HALF_OFFSET
    lock xchg [rcx], rax
    mov  rcx, ENTRY_POINT_ADDR + HIGHER_HALF_OFFSET
    mov  [rcx], rdi
    mov  rax, cr3
    mov  rcx, PAGEMAP_PTR      + HIGHER_HALF_OFFSET
    mov  [rcx], rax
    mov  rcx, STACK_PTR        + HIGHER_HALF_OFFSET
    mov  [rcx], rsi
    mov  rcx, CPU_NUMBER       + HIGHER_HALF_OFFSET
    mov  [rcx], rdx
    mov  rcx, GDT_PTR_LOWER    + HIGHER_HALF_OFFSET
    sgdt [rcx]
    mov  rax, HIGHER_HALF_OFFSET
    mov  rcx, GDT_PTR_LOWER    + HIGHER_HALF_OFFSET + 2
    sub  [rcx], rax
    mov  rcx, GDT_PTR          + HIGHER_HALF_OFFSET
    sgdt [rcx]
    mov  rcx, IDT_PTR          + HIGHER_HALF_OFFSET
    sidt [rcx]

    mov rdi, TRAMPOLINE_ADDR + HIGHER_HALF_OFFSET
    mov rsi, trampoline
    mov rcx, trampoline.end - trampoline
    rep movsb

    mov rax, TRAMPOLINE_ADDR
    ret

section .data

bits 16
trampoline:
    cli
    cld

    jmp 0:0x1007    ; 0x1007 is the address of the next instruction
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    lgdt [GDT_PTR_LOWER]

    mov eax, [PAGEMAP_PTR]
    mov cr3, eax

    mov eax, cr4
    or  eax, 1 << 5
    mov cr4, eax

    mov ecx, 0xc0000080
    rdmsr
    or  eax, 1 << 8
    wrmsr

    mov eax, cr0
    or  eax, 0x80000001
    and eax, ~0x60000000
    mov cr0, eax

    jmp 0x08:0x1050    ; 0x1050 is the address of the next instruction
bits 64
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov rcx, STACK_PTR + HIGHER_HALF_OFFSET
    mov rsp, [rcx]

    mov rcx, GDT_PTR + HIGHER_HALF_OFFSET
    lgdt [rcx]
    mov rcx, IDT_PTR + HIGHER_HALF_OFFSET
    lidt [rcx]

    mov rcx, CPU_NUMBER + HIGHER_HALF_OFFSET
    mov rdi, [rcx]
    mov rcx, ENTRY_POINT_ADDR + HIGHER_HALF_OFFSET
    mov rbx, [rcx]

    mov rcx, CPU_STARTED_FLAG + HIGHER_HALF_OFFSET
    mov eax, 1
    lock xchg [rcx], rax

    call rbx
  .end:
