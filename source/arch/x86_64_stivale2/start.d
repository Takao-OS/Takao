// Start function for the stivale protocol.
module arch.x86_64_stivale2.start;

import arch.x86_64_stivale2.acpi:        initACPI;
import arch.x86_64_stivale2.protocol;    // Everything really.
import arch.x86_64_stivale2.gdt:         initGDT;
import arch.x86_64_stivale2.idt:         initIDT;
import arch.x86_64_stivale2.pic:         initPIC;
import arch.x86_64_stivale2.pit:         initPIT, enablePIT;
import arch.x86_64_stivale2.memmap:      translateStivaleMemmap;
import arch.x86_64_stivale2.madt:        initMADT;
import arch.x86_64_stivale2.apic:        initAPIC;
import arch.x86_64_stivale2.ps2mouse:    initPS2Mouse;
import arch.x86_64_stivale2.ps2keyboard: initPS2Keyboard;
import arch.x86_64_stivale2.smp:         initSMP;
import arch.x86_64_stivale2.cpu:         initCPULocals, initCPU;
import arch.x86_64_stivale2.devices:     scanDevices;
import lib.string:                       fromCString;
import lib.panic:                        panic;
import memory.physical:                  PhysicalAllocator;
import archinterface:                    enableInterrupts, disableInterrupts;
import kernelprotocol:                   KernelProtocol, KernelDevice;
import main:                             mainAllocator, kernelMain;

debug import lib.debugtools: log;

/// Start function.
extern (C) void start(Stivale2* proto) {
    auto cmdline = getStivale2Tag!Stivale2Cmdline(proto);
    auto fb      = getStivale2Tag!Stivale2Framebuffer(proto);
    auto memmap  = getStivale2Tag!Stivale2Memmap(proto);
    auto rsdp    = getStivale2Tag!Stivale2RSDP(proto);
    auto smpinfo = getStivale2Tag!Stivale2SMP(proto);
    if (cmdline == null || fb == null || memmap == null || rsdp == null || smpinfo == null) {
        panic("The bootloader didn't provide all the stuff we need");
    }
    debug proto.debugPrint();
    debug cmdline.debugPrint();
    debug fb.debugPrint();
    debug memmap.debugPrint();
    debug rsdp.debugPrint();

    debug log("Initializing low level structures");
    initGDT();
    initIDT();

    debug log("Initializing freestanding memory management");
    auto protomemmap = translateStivaleMemmap(memmap);
    mainAllocator    = PhysicalAllocator(protomemmap);

    debug log("Parsing basic ACPI information");
    initACPI(rsdp.rsdp);
    initMADT();

    debug log("Initializing CPU locals");
    initCPULocals(smpinfo.cpuCount);
    initCPU(0, 0);

    debug log("Initializing several cute devices");
    initPIC();
    initAPIC();
    initPIT();
    initPS2Mouse();
    initPS2Keyboard();
    enablePIT();

    debug log("Starting SMP");
    enableInterrupts();
    initSMP(smpinfo);

    debug log("Jumping to freestanding kernel");
    KernelProtocol kproto;
    kproto.cmdline    = fromCString(cast(char*)cmdline.cmdline);
    kproto.fb.address = fb.address;
    kproto.fb.width   = fb.width;
    kproto.fb.height  = fb.height;
    kproto.fb.pitch   = fb.pitch;
    kproto.fb.bpp     = fb.bpp;
    kproto.mmap       = protomemmap;
    kproto.devices    = scanDevices();
    kernelMain(kproto);
}
