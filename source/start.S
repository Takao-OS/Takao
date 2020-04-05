.section .stivalehdr, "aw"

header:
    .quad stackTop // rsp
    .word 1        // video mode
    .word 0        // fb_width, 0 is default
    .word 0        // fb_height, ditto
    .word 0        // fb_bpp, ditto

.section .bss

.align 16
stack:
    .space 4096
stackTop:
