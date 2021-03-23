module main;

import stivale2:        getStivale2Tag, Stivale2, Stivale2MemoryMap, Stivale2Framebuffer, Stivale2RSDP;
import system.gdt:      initGDT;
import system.idt:      initIDT;
import system.pic:      initPIC;
import system.pit:      initPIT, enablePIT;
import memory.physical: initPhysicalAllocator;
import memory.virtual:  AddressSpace, MEM_PHYS_OFFSET;
import lib.panic:       panic;
import acpi.lib:        initACPI, RSDP;
import system.apic:     initAPIC;
import system.cpu:      initCPU, initCPULocals;
import system.smp:      initSMP;
import wm.driver:       initWM, showLoadingScreen;
debug import lib.debugtools: log;

extern (C) void main(Stivale2* stivale) {
    debug log("Hai~ <3. Doing some preparatives");
    stivale = cast(Stivale2*)(cast(size_t)stivale + MEM_PHYS_OFFSET);
    auto memmap = getStivale2Tag!Stivale2MemoryMap(stivale);
    auto fb     = getStivale2Tag!Stivale2Framebuffer(stivale);
    auto rsdp   = getStivale2Tag!Stivale2RSDP(stivale);
    if (memmap == null || fb == null || rsdp == null) {
        panic("Stivale2 did not provide all of the needed info");
    }

    debug log("Initialising low level structures and devices.");
    initGDT();
    initIDT();

    debug log("Initialising memory management");
    initPhysicalAllocator(memmap);
    auto as = AddressSpace(memmap);
    as.setActive();

    debug log("Initialize the WM");
    initWM(fb);
    showLoadingScreen();

    debug log("Init CPU");
    initCPULocals();
    initCPU(0, 0);

    debug log("Initialising ACPI");
    initACPI(cast(RSDP*)(rsdp.rsdp + MEM_PHYS_OFFSET));

    debug log("Initialising interrupt controlling and timer");
    initPIC();
    initAPIC();
    initPIT();
    enablePIT();

    asm { sti; }
    initSMP();

    for (;;) asm { hlt; }
}
