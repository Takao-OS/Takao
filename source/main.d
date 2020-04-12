module main;

import lib.stivale;
import system.gdt;
import system.idt;
import system.pic;
import system.pit;
import memory.physical;
import memory.virtual;
import lib.messages;
import scheduler.thread;
import services.kmessage;
import services.terminal;
import acpi.lib;
import system.apic;
import system.cpu;
import lib.pci;

__gshared bool servicesUp;

extern (C) void main(Stivale* stivale) {
    log("Hai~ <3. Doing some preparatives");
    stivale = cast(Stivale*)(cast(size_t)stivale + MEM_PHYS_OFFSET);

    log("Initialising low level structures and devices.");
    initGDT();
    initIDT();
    initPIC();

    log("Initialising memory management and GC");
    initPhysicalAllocator(stivale.memmap);
    auto as = AddressSpace(stivale.memmap);
    as.setActive();

    initCPULocals();
    initCPU(0, 0);

    log("Initialising ACPI");
    initACPI(cast(RSDP*)(stivale.rsdp + MEM_PHYS_OFFSET));

    initAPIC();

    initPIT();
    enablePIT();
    initPCI();

    log("Spawning main thread");
    spawnThread(&mainThread, stivale);
    asm { sti; }

    for (;;) asm { hlt; }
}

extern (C) void mainThread(Stivale* stivale) {
    log("Spawning services, switching to kmessage");
    servicesUp = true;
    spawnThread(&kmessageService, null);
    spawnThread(&terminalService, &stivale.framebuffer);

    for (;;) {
        dequeueAndYield();
    }
}
