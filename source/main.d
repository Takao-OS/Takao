module main;

import stivale2;
import system.gdt;
import system.idt;
import system.pic;
import system.pit;
import memory.physical;
import memory.virtual;
debug import lib.debugtools;
import lib.panic;
import acpi.lib;
import system.apic;
import system.cpu;
import system.smp;
import wm.driver: initWM, showLoadingScreen;

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
