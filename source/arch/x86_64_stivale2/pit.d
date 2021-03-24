module arch.x86_64_stivale2.pit;

import arch.x86_64_stivale2.cpu;
import arch.x86_64_stivale2.apic;
import core.volatile;

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

private __gshared size_t globalTicks;

void tickHandler() {
    globalTicks++;
}

void sleep(size_t ticks) {
    size_t target = volatileLoad(&globalTicks) + ticks;
    while (volatileLoad(&globalTicks) < target) {}
}
