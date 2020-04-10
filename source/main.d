module main;

import lib.stivale;
import system.gdt;
import system.idt;
import system.pic;
import system.pit;
import memory.physical;
import memory.virtual;
import lib.debugging;
import scheduler.thread;
import services.kmessage;
import services.terminal;
import acpi.lib;

extern (C) void main(Stivale* stivale) {
    writeln("Hai~ <3. Doing some preparatives");
    stivale = cast(Stivale*)(cast(size_t)stivale + MEM_PHYS_OFFSET);

    writeln("Initialising low level structures and devices.");
    initGDT();
    initPIT();
    initPIC();
    initIDT();

    writeln("Initialising memory management and GC");
    initPhysicalAllocator(stivale.memmap);
    auto as = AddressSpace(stivale.memmap);
    as.setActive();

    initACPI(cast(RSDP*)(stivale.rsdp + MEM_PHYS_OFFSET));

    spawnThread(&mainThread, stivale);

    asm { sti; }

    for (;;) asm { hlt; }
}

extern (C) void mainThread(Stivale* stivale) {
    writeln("Spawning services");

    spawnThread(&kmessageService, null);
    spawnThread(&terminalService, &stivale.framebuffer);

    for (;;) {
        dequeueAndYield();
    }
}
