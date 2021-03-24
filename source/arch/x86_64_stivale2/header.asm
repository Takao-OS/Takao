section .stivale2hdr

header:
    dq 0              ; Alternative entrypoint, 0 is none.
    dq stackTop       ; Stack to be loaded for the kernel.
    dq 0              ; Flags, we dont need anything in particular.
    dq framebufferTag ; Start of tags.

section .text

framebufferTag:
    dq 0x3ecc1bc43d0f7971 ; Identifier of the tag.
    dq smpTag             ; Next in line.
    dw 0                  ; Prefered width, 0 for default.
    dw 0                  ; Ditto.
    dw 0                  ; Ditto.

smpTag:
    dq 0x1ab015085f3273df ; Identifier of the tag.
    dq 0                  ; Next one in line, 0 is none.
    dq 0                  ; Flags, we dont need anything in particular.

section .bss
align 16

stack:
    resb 32768
stackTop:
