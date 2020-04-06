ENTRY(main)

SECTIONS {
    . = 0xffffffff80100000;

    /* Name required by spec. */
    .stivalehdr : ALIGN(4K) {
        KEEP(*(.stivalehdr))
    }

    /* Actual kernel. */
    .text : ALIGN(4K) {
        *(.text*)
    }

    .rodata : ALIGN(4K) {
        *(.rodata*)
    }

    .data : ALIGN(4K) {
        *(.data*)
    }

    .bss : ALIGN(4K) {
        *(.bss*)
        *(COMMON)
        . = ALIGN(4K);
        kernelTop = .;
    }
}

