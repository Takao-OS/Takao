module main;

import stivale2;
import system.gdt;
import system.idt;
import system.pic;
import system.pit;
import memory.physical;
import memory.virtual;
import lib.messages;
import lib.panic;
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

extern (C) void main(Stivale2* stivale) {
    log("Hai~ <3. Doing some preparatives");
    stivale = cast(Stivale2*)(cast(size_t)stivale + MEM_PHYS_OFFSET);
    auto memmap = getStivale2Tag!Stivale2MemoryMap(stivale);
    auto fb     = getStivale2Tag!Stivale2Framebuffer(stivale);
    auto rsdp   = getStivale2Tag!Stivale2RSDP(stivale);
    if (memmap == null || fb == null || rsdp == null) {
        panic("Stivale2 did not provide all of the needed info");
    }

    log("Initialising low level structures and devices.");
    initGDT();
    initIDT();

    log("Initialising memory management");
    initPhysicalAllocator(memmap);
    auto as = AddressSpace(memmap);
    as.setActive();

    log("Init CPU");
    initCPULocals();
    initCPU(0, 0);

    log("Initialising ACPI");
    initACPI(cast(RSDP*)(rsdp.rsdp + MEM_PHYS_OFFSET));

    log("Initialising interrupt controlling and timer");
    initPIC();
    initAPIC();
    initPIT();
    enablePIT();

    disableScheduler();

    asm { sti; }

    initSMP();

    log("Spawning main thread");
    spawnThread(&mainThread, fb);

    enableScheduler();

    for (;;) asm { hlt; }
}

extern (C) void mainThread(Stivale2Framebuffer* fb) {
    log("Spawning services, switching to kmessage");
    spawnThread(&kmessageService, null);
    spawnThread(&pciService,      null);
    spawnThread(&storageService,  null);
    spawnThread(&terminalService, fb);
    servicesUp = true;

    for (;;) {
        dequeueAndYield();
    }
}
