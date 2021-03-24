; Save registers.
%macro pusham 0
    cld
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
%endmacro

%macro popam 0
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
%endmacro

extern exceptionHandler

%macro exceptHandlerErrCode 1
    push qword [rsp+5*8]
    push qword [rsp+5*8]
    push qword [rsp+5*8]
    push qword [rsp+5*8]
    push qword [rsp+5*8]
    pusham
    mov rdi, %1
    mov rsi, rsp
    mov rdx, qword [rsp+20*8]
    call exceptionHandler
    popam
    iretq
%endmacro

%macro exceptHandler 1
    pusham
    mov rdi, %1
    mov rsi, rsp
    xor rdx, rdx
    call exceptionHandler
    popam
    iretq
%endmacro

section .text

; Exception handlers
global excDiv0Handler
excDiv0Handler:
    exceptHandler 0x0
global excDebugHandler
excDebugHandler:
    exceptHandler 0x1
global excNmiHandler
excNmiHandler:
    exceptHandler 0x2
global excBreakpointHandler
excBreakpointHandler:
    exceptHandler 0x3
global excOverflowHandler
excOverflowHandler:
    exceptHandler 0x4
global excBoundRangeHandler
excBoundRangeHandler:
    exceptHandler 0x5
global excInvOpcodeHandler
excInvOpcodeHandler:
    exceptHandler 0x6
global excNoDevHandler
excNoDevHandler:
    exceptHandler 0x7
global excDoubleFaultHandler
excDoubleFaultHandler:
    exceptHandlerErrCode 0x8
global excInvTssHandler
excInvTssHandler:
    exceptHandlerErrCode 0xa
global excNoSegmentHandler
excNoSegmentHandler:
    exceptHandlerErrCode 0xb
global excSsFaultHandler
excSsFaultHandler:
    exceptHandlerErrCode 0xc
global excGpfHandler
excGpfHandler:
    exceptHandlerErrCode 0xd
global excPageFaultHandler
excPageFaultHandler:
    exceptHandlerErrCode 0xe
global excX87FpHandler
excX87FpHandler:
    exceptHandler 0x10
global excAlignmentCheckHandler
excAlignmentCheckHandler:
    exceptHandlerErrCode 0x11
global excMachineCheckHandler
excMachineCheckHandler:
    exceptHandler 0x12
global excSimdFpHandler
excSimdFpHandler:
    exceptHandler 0x13
global excVirtHandler
excVirtHandler:
    exceptHandler 0x14
global excSecurityHandler
excSecurityHandler:
    exceptHandlerErrCode 0x1e
