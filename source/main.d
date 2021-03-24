/// Main function of the freestanding kernel, and its most immediate utilities.
module main;

import display.wm:      initWM, loadingScreen, refresh, addWindow;
import display.window:  Window;
import lib.cmdline:     getCmdlineOption;
import lib.panic:       panic;
import memory.physical: initPhysicalAllocator;
import storage.driver:  initStorageSubsystem;
import storage.file:    openFile, fileLength, readFile, FileMode;
import archinterface:   enableInterrupts, disableInterrupts, executeCore, killCore, getCoreCount, getCurrentCore;
import kernelprotocol:  KernelProtocol;
debug import lib.debugtools: log;

/// Main function of the kernel.
/// The state when the function is called must be:
///     - All cores but the one executing this function must be halting.
///     - Interrupts can be on or off.
///     - Flat addressing, no paging or anything.
///     - The memory allocator must be already initialized by calling
///       `initPhysicalAllocator`, this is done for ports that might require
///       memory management for hardware initialization purposes.
void kernelMain(KernelProtocol proto) {
    debug log("Hi from the freestanding kernel!");
    debug proto.debugPrint();
    disableInterrupts();

    debug log("Starting WM");
    initWM(proto.fb);
    loadingScreen();

    debug log("Starting storage subsystem");
    initStorageSubsystem();

    debug log("Loading init");
    const useInit = getCmdlineOption(proto.cmdline, "useInit");
    if (useInit != "false") {
        const initPath = getCmdlineOption(proto.cmdline, "init");
        if (initPath == null) {
            panic("No init specified");
        }
        const fd = openFile(initPath, FileMode.Read);
        if (fd == -1) {
            panic("Could not open init");
        }
    }

    debug log("Starting refresh cycle");
    enableInterrupts();

    const cores = getCoreCount();
    const curr  = getCurrentCore();
    foreach (i; 0..cores) {
        if (i == curr) {
            addWindow(Window("Hey its current!", 100, 100));
        } else {
            executeCore(i, () {
                addWindow(Window("Lol", 100, 100));
                killCore();
            });
        }
    }

    for (;;) { refresh(); }

    panic("End of kernel");
}
