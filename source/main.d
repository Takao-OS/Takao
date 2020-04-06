module main;

import lib.stivale;
import system.gdt;
import system.idt;
import system.pic;
import system.pit;
import memory.physical;
import memory.virtual;
import lib.debugging;
import lib.gc;
import scheduler.thread;
import services.kmessage;
import services.wm;

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

    writeln("Spawning services");

    spawnThread(&kmessageService, null);
    spawnThread(&wmService,       &stivale.framebuffer);
    asm { sti; }

    for (;;) asm { hlt; }
}
