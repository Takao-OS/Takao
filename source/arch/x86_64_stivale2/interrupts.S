.intel_syntax noprefix
.extern exceptionHandler

#define PUSHAM \
    cld;       \
    push rax;  \
    push rbx;  \
    push rcx;  \
    push rdx;  \
    push rsi;  \
    push rdi;  \
    push rbp;  \
    push r8;   \
    push r9;   \
    push r10;  \
    push r11;  \
    push r12;  \
    push r13;  \
    push r14;  \
    push r15

#define POPAM \
    pop r15;  \
    pop r14;  \
    pop r13;  \
    pop r12;  \
    pop r11;  \
    pop r10;  \
    pop r9;   \
    pop r8;   \
    pop rbp;  \
    pop rdi;  \
    pop rsi;  \
    pop rdx;  \
    pop rcx;  \
    pop rbx;  \
    pop rax

#define HANDLER_ERRCODE(num)       \
    push qword ptr [rsp+5*8];      \
    push qword ptr [rsp+5*8];      \
    push qword ptr [rsp+5*8];      \
    push qword ptr [rsp+5*8];      \
    push qword ptr [rsp+5*8];      \
    PUSHAM;                        \
    mov rdi, num;                  \
    mov rsi, rsp;                  \
    mov rdx, qword ptr [rsp+20*8]; \
    call exceptionHandler;         \
    POPAM;                         \
    iretq

#define HANDLER(num)       \
    PUSHAM;                \
    mov rdi, num;          \
    mov rsi, rsp;          \
    xor rdx, rdx;          \
    call exceptionHandler; \
    POPAM;                 \
    iretq

.section .text

// Exception handlers
.global excDiv0Handler
.global excDebugHandler
.global excNmiHandler
.global excBreakpointHandler
.global excOverflowHandler
.global excBoundRangeHandler
.global excInvOpcodeHandler
.global excNoDevHandler
.global excDoubleFaultHandler
.global excInvTssHandler
.global excNoSegmentHandler
.global excSsFaultHandler
.global excGpfHandler
.global excPageFaultHandler
.global excX87FpHandler
.global excAlignmentCheckHandler
.global excMachineCheckHandler
.global excSimdFpHandler
.global excVirtHandler
.global excSecurityHandler

excDiv0Handler:           HANDLER(0x0)
excDebugHandler:          HANDLER(0x1)
excNmiHandler:            HANDLER(0x2)
excBreakpointHandler:     HANDLER(0x3)
excOverflowHandler:       HANDLER(0x4)
excBoundRangeHandler:     HANDLER(0x5)
excInvOpcodeHandler:      HANDLER(0x6)
excNoDevHandler:          HANDLER(0x7)
excDoubleFaultHandler:    HANDLER_ERRCODE(0x8)
excInvTssHandler:         HANDLER_ERRCODE(0xa)
excNoSegmentHandler:      HANDLER_ERRCODE(0xb)
excSsFaultHandler:        HANDLER_ERRCODE(0xc)
excGpfHandler:            HANDLER_ERRCODE(0xd)
excPageFaultHandler:      HANDLER_ERRCODE(0xe)
excX87FpHandler:          HANDLER(0x10)
excAlignmentCheckHandler: HANDLER_ERRCODE(0x11)
excMachineCheckHandler:   HANDLER(0x12)
excSimdFpHandler:         HANDLER(0x13)
excVirtHandler:           HANDLER(0x14)
excSecurityHandler:       HANDLER_ERRCODE(0x1e)
