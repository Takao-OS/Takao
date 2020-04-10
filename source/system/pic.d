module system.pic;

import system.cpu;

immutable PIC_EOI = 0x20;

immutable MASTERPIC_COMMAND = 0x20;
immutable MASTERPIC_DATA    = 0X21;
immutable SLAVEPIC_COMMAND  = 0xA0;
immutable SLAVEPIC_DATA     = 0xA1;

void initPIC() {
    auto masterPICMask = inb(MASTERPIC_DATA);
    auto slavePICMask  = inb(SLAVEPIC_DATA);

    outb(MASTERPIC_COMMAND, 0x11);
    outb(SLAVEPIC_COMMAND, 0x11);

    outb(MASTERPIC_DATA, 0x20);
    outb(SLAVEPIC_DATA, 0x28);

    outb(MASTERPIC_DATA, 4); // Tell master that the slave PIC is at IRQ2 (0000 0100)
    outb(SLAVEPIC_DATA, 2); // Tell the slave PIC its cascade identity (0000 0010)

    outb(MASTERPIC_DATA, 1);
    outb(SLAVEPIC_DATA, 1);

    // Restore the masks
    outb(MASTERPIC_DATA, masterPICMask);
    outb(SLAVEPIC_DATA, slavePICMask);
}
