/// Main function of the freestanding kernel, and its most immediate utilities.
module main;

import display.wm:      WM;
import display.window:  Window;
import lib.cmdline:     getCmdlineOption;
import lib.panic:       panic;
import memory.physical: PhysicalAllocator;
import memory.virtual:  VirtualSpace;
import storage.driver:  initStorageSubsystem;
import storage.file:    open, close, FileMode;
import archinterface:   enableInterrupts, disableInterrupts, executeCore, killCore, getCoreCount, getCurrentCore;
import kernelprotocol:  KernelProtocol;
debug import lib.debugtools: log;

__gshared WM                mainWM;        /// Main window manager.
__gshared PhysicalAllocator mainAllocator; /// Main allocator.
__gshared VirtualSpace      mainMappings;  /// Main virtual mappings.

/// Main function of the kernel.
/// The state when the function is called must be:
///     - All cores but the one executing this function must be halting.
///     - Interrupts can be on or off.
///     - Flat addressing, no paging or anything.
///     - The memory allocator must be already initialized, this is done for
///       ports that might require memory management for hardware initialization
///       purposes.
void kernelMain(KernelProtocol proto) {
    debug log("Hi from the freestanding kernel!");
    debug proto.debugPrint();
    disableInterrupts();
panic("A");
    debug log("Creating and activating main mappings");
    mainMappings = VirtualSpace(proto.mmap);
    mainMappings.setActive();

    debug log("Starting WM");
    mainWM = WM(proto.fb);
    mainWM.loadingScreen();

    debug log("Starting storage subsystem");
    initStorageSubsystem();

    debug log("Loading init if any");
    if (proto.cmdline != null) {
        const init = getCmdlineOption(proto.cmdline, "useInit");
        if (init != null) {
            const fd = open(init, FileMode.Read);
            if (fd == -1) {
                panic("Could not open init");
            }
            close(fd);
        }
    }

    debug log("Doing last minute preparations");
    enableInterrupts();

    const cores = getCoreCount();
    const curr  = getCurrentCore();
    foreach (i; 0..cores) {
        if (i == curr) {
            mainWM.createWindow("Hey its current!");
        } else {
            executeCore(i, () {
                mainWM.createWindow("Lol");
                killCore();
            });
        }
    }

    debug log("Starting refresh cycle");
    for (;;) {
        mainWM.refresh();
    }

    panic("End of kernel");
}
