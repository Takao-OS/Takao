.section ".stivale2hdr", "aw", @progbits

header:
    .quad 0              // Alternative entrypoint, 0 is none.
    .quad stackTop       // Stack to be loaded for the kernel.
    .quad 0              // Flags, we dont need anything in particular.
    .quad framebufferTag // Start of tags.

.section .data

framebufferTag:
    .quad 0x3ecc1bc43d0f7971 // Identifier of the tag.
    .quad smpTag             // Next in line.
    .word 0                  // Prefered width, 0 for default.
    .word 0                  // Ditto.
    .word 0                  // Ditto.

smpTag:
    .quad 0x1ab015085f3273df // Identifier of the tag.
    .quad 0                  // Next one in line, 0 is none.
    .quad 0                  // Flags, we dont need anything in particular.

.section .bss
.align 16

stack:
    .space 32768
stackTop:
