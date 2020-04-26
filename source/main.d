module main;

import stivale;
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
import services.pci;
import services.storage;
import acpi.lib;
import system.apic;
import system.cpu;
import system.smp;

__gshared bool servicesUp;

extern (C) void main(Stivale* stivale) {
    log("Hai~ <3. Doing some preparatives");
    stivale = cast(Stivale*)(cast(size_t)stivale + MEM_PHYS_OFFSET);

    log("Initialising low level structures and devices.");
    initGDT();
    initIDT();

    log("Initialising memory management and GC");
    initPhysicalAllocator(stivale.memmap);
    auto as = AddressSpace(stivale.memmap);
    as.setActive();

    terminalEarlyInit(stivale.framebuffer);

    log("Init CPU");
    initCPULocals();
    initCPU(0, 0);

    log("Initialising ACPI");
    initACPI(cast(RSDP*)(stivale.rsdp + MEM_PHYS_OFFSET));

    log("Initialising interrupt controlling and timer");
    initPIC();
    initAPIC();
    initPIT();
    enablePIT();

    disableScheduler();

    asm { sti; }

    initSMP();

    log("Spawning main thread");
    spawnThread(&mainThread, stivale);

    enableScheduler();

    for (;;) asm { hlt; }
}

extern (C) void mainThread(Stivale* stivale) {
    log("Spawning services, switching to kmessage");
    servicesUp = true;
    spawnThread(&kmessageService, null);
    spawnThread(&pciService,      null);
    spawnThread(&storageService,  null);
    spawnThread(&terminalService, null);

    for (;;) {
        dequeueAndYield();
    }
}
