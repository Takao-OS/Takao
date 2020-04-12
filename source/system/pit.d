module system.pit;

import system.cpu;
import system.apic;

private immutable ushort pitFrequency = 1000;

void initPIT() {
    uint divisor = 1193180 / pitFrequency;

    outb(0x43, 0x36);

    ubyte l = cast(ubyte)(divisor & 0xFF);
    ubyte h = cast(ubyte)((divisor >> 8) & 0xFF);

    outb(0x40, l);
    outb(0x40, h);
}

void enablePIT() {
    ioAPICSetUpLegacyIRQ(0, 0, true);
}
