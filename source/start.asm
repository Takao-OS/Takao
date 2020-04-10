section .stivalehdr

header:
    dq stack.top ; rsp
    dw 0         ; video mode
    dw 0         ; fb_width, 0 is default
    dw 0         ; fb_height, ditto
    dw 0         ; fb_bpp, ditto

section .bss

align 16
stack:
    resb 32768
  .top:
