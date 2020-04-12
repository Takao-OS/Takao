module system.pic;

import system.cpu;

immutable PIC_EOI = 0x20;

immutable MASTERPIC_COMMAND = 0x20;
immutable MASTERPIC_DATA    = 0X21;
immutable SLAVEPIC_COMMAND  = 0xA0;
immutable SLAVEPIC_DATA     = 0xA1;

void initPIC() {
    outb(MASTERPIC_COMMAND, 0x11);
    outb(SLAVEPIC_COMMAND, 0x11);

    outb(MASTERPIC_DATA, 0xa0);
    outb(SLAVEPIC_DATA, 0xa8);

    outb(MASTERPIC_DATA, 4); // Tell master that the slave PIC is at IRQ2 (0000 0100)
    outb(SLAVEPIC_DATA, 2); // Tell the slave PIC its cascade identity (0000 0010)

    outb(MASTERPIC_DATA, 1);
    outb(SLAVEPIC_DATA, 1);

    // Restore the masks
    outb(MASTERPIC_DATA, 0xff);
    outb(SLAVEPIC_DATA, 0xff);
}
