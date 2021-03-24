/// Code related to the IBM PC Programable Interrupt Controller, or PIC.
module arch.x86_64_stivale2.pic;

private immutable masterPICCommand = 0x20;
private immutable masterPICData    = 0X21;
private immutable slavePICCommand  = 0xa0;
private immutable slavePICData     = 0xa1;

/// Initialize the PIC by remapping it to a proper location.
void initPIC() {
    import arch.x86_64_stivale2.cpu: outb;

    outb(masterPICCommand, 0x11);
    outb(slavePICCommand,  0x11);

    outb(masterPICData, 0xa0);
    outb(slavePICData,  0xa8);

    outb(masterPICData, 4); // Tell master that the slave PIC is at IRQ2 (0000 0100)
    outb(slavePICData,  2); // Tell the slave PIC its cascade identity (0000 0010)

    outb(masterPICData, 1);
    outb(slavePICData,  1);

    // Restore the masks
    outb(masterPICData, 0xff);
    outb(slavePICData,  0xff);
}
