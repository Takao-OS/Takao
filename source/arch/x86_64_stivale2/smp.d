/// Managing core initialization and control.
module arch.x86_64_stivale2.smp;

import arch.x86_64_stivale2.protocol: Stivale2SMP, Stivale2SMPEntry;

private immutable size_t cpuStackSize = 32_768;

shared size_t cpuCount = 0; /// Count of initialized cores in the system.

/// Initialize the other cores of the system.
/// Params:
///     smpInfo = SMP information, not null.
void initSMP(Stivale2SMP* smpinfo) {
    import arch.x86_64_stivale2.cpu: initCPU;
    import memory.alloc:             allocate;
    import core.volatile:            volatileStore;
    import lib.panic:                panic;

    assert(smpinfo != null);

    size_t count = 0;
    auto cores   = &smpinfo.entries;
    foreach (i; 0..smpinfo.cpuCount) {
        count++;
        if (cores[i].lapicID == smpinfo.bspLAPICID) {
            continue;
        }

        const stack = allocate!ubyte(cpuStackSize);
        if (allocate == null) {
            panic("Could not allocate core's stack");
        }

        volatileStore(&cores[i].stack, cast(ulong)stack + cpuStackSize);
        volatileStore(&cores[i].argument, i);
        volatileStore(&cores[i].gotoAddress, cast(ulong)&initCore);
    }

    cpuCount = count;
}

private extern (C) void initCore(Stivale2SMPEntry* info) {
    import arch.x86_64_stivale2.gdt: loadGDT;
    import arch.x86_64_stivale2.idt: loadIDT;
    import arch.x86_64_stivale2.cpu: initCPU;
    debug import lib.debugtools:     log;
    import archinterface:            getCurrentCore, enableInterrupts;

    loadGDT();
    loadIDT();
    initCPU(cast(uint)info.argument, cast(ubyte)info.lapicID);
    enableInterrupts();
    debug log("Started core ", getCurrentCore());

    while (true) {
        asm { hlt; }
    }
}
