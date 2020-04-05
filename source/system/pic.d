module system.pic;

import system.intrinsics;

immutable PIC_EOI = 0x20;

immutable MASTERPIC_COMMAND = 0x20;
immutable MASTERPIC_DATA    = 0X21;
immutable SLAVEPIC_COMMAND  = 0xA0;
immutable SLAVEPIC_DATA     = 0xA1;

void initPIC() {
    auto masterPICMask = inb(MASTERPIC_DATA);
    auto slavePICMask  = inb(SLAVEPIC_DATA);

    outb(MASTERPIC_COMMAND, 0x11);
    wait();
    outb(SLAVEPIC_COMMAND, 0x11);
    wait();

    outb(MASTERPIC_DATA, 0x20);
    wait();
    outb(SLAVEPIC_DATA, 0x28);
    wait();

    outb(MASTERPIC_DATA, 4); // Tell master that the slave PIC is at IRQ2 (0000 0100)
    wait();
    outb(SLAVEPIC_DATA, 2); // Tell the slave PIC its cascade identity (0000 0010)
    wait();

    outb(MASTERPIC_DATA, 1);
    wait();
    outb(SLAVEPIC_DATA, 1);
    wait();

    // Restore the masks
    outb(MASTERPIC_DATA, masterPICMask);
    wait();
    outb(SLAVEPIC_DATA, slavePICMask);
    wait();
}
