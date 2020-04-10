module cpu.pit;

import system.cpu;

private immutable ushort pitFrequency = 1000;

void initPIT() {
    uint divisor = 1193180 / pitFrequency;

    outb(0x43, 0x36);

    ubyte l = cast(ubyte)(divisor & 0xFF);
    ubyte h = cast(ubyte)((divisor >> 8) & 0xFF);

    outb(0x40, l);
    outb(0x40, h);
}
