section .text

%define HIGHER_HALF_OFFSET 0xffff800000000000
%define TRAMPOLINE_ADDR    0x1000

%define LAPIC_ID         0x2000
%define ENTRY_POINT_ADDR 0x2008
%define PAGEMAP_PTR      0x2010
%define STACK_PTR        0x2018
%define CPU_NUMBER       0x2020
%define GDT_PTR_LOWER    0x2030
%define GDT_PTR          0x2040
%define IDT_PTR          0x2050

global smpPrepareTrampoline
smpPrepareTrampoline: ; (entryPoint, stackPtr, cpuNumber, lapicID)
    mov  [ENTRY_POINT_ADDR], rdi
    mov  [STACK_PTR],        rsi
    mov  [CPU_NUMBER],       rdx
    mov  [LAPIC_ID],         rcx

    mov  rax, cr3
    mov  [PAGEMAP_PTR], rax
    sgdt [GDT_PTR_LOWER]
    mov  rax, HIGHER_HALF_OFFSET
    sub  [GDT_PTR_LOWER+2], rax
    sgdt [GDT_PTR]
    sidt [IDT_PTR]

    mov rdi, TRAMPOLINE_ADDR
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

    mov rsp, [STACK_PTR]

    lgdt [GDT_PTR]
    lidt [IDT_PTR]

    mov rdi, [CPU_NUMBER]
    mov rsi, [LAPIC_ID]

    call [ENTRY_POINT_ADDR]
  .end:
