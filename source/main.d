/// Main function of the freestanding kernel, and its most immediate utilities.
module main;

import display.wm:      WM;
import display.window:  Window, TextWidget;
import lib.cmdline:     getCmdlineOption;
import lib.panic:       panic;
import lib.string:      buildStringInPlace, fromCString;
import memory.physical: PhysicalAllocator;
import memory.virtual:  VirtualSpace;
import storage.driver:  initStorageSubsystem;
import storage.file:    open, close, FileMode;
import archinterface:   enableInterrupts, disableInterrupts, executeCore, killCore, getCoreCount, getCurrentCore;
import kernelprotocol:  KernelProtocol;
debug import lib.debugtools: log, error;

private immutable boldFontPath    = ":bold.psf";
private immutable cursiveFontPath = ":cursive.psf";
private immutable sansFontPath    = ":sans.psf";

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
void kernelMain(const ref KernelProtocol proto) {
    debug log("Hi from the freestanding kernel!");
    debug proto.debugPrint();
    disableInterrupts();

    debug log("Creating and activating main mappings");
    mainMappings = VirtualSpace(proto.mmap);
    mainMappings.setActive();

    debug log("Starting WM");
    mainWM = WM(proto.fb);
    mainWM.loadingScreen();

    debug log("Starting storage subsystem");
    initStorageSubsystem();

    debug log("Fetch commandline options");
    string init;
    string root;
    if (proto.cmdline != null) {
        init = getCmdlineOption(proto.cmdline, "init");
        root = getCmdlineOption(proto.cmdline, "root");
    }

    debug log("Loading init if any");
    if (init != null) {
        const fd = open(init, FileMode.Read);
        if (fd == -1) {
            debug error("Could not open init");
        } else {
            close(fd);
        }
    }

    debug log("Doing last minute preparations");
    enableInterrupts();
    if (root != null) {
        char[256] path;
        size_t    len;
        len = buildStringInPlace(path.ptr, path.length, root, boldFontPath); 
        mainWM.loadBoldFont(fromCString(path.ptr, len));
        len = buildStringInPlace(path.ptr, path.length, root, cursiveFontPath);
        mainWM.loadCursiveFont(fromCString(path.ptr, len));
        len = buildStringInPlace(path.ptr, path.length, root, sansFontPath);
        mainWM.loadSansFont(fromCString(path.ptr, len));
    }

    auto wh = mainWM.createWindow("Hello!");
    if (wh == -1) {
        panic("Could not create window");
    }
    auto win = mainWM.fetchWindow(wh);
    if (win == null) {
        panic("Could not fetch welcome window");
    }
    win.resize(100, 100);
    win.addWidget(TextWidget(false, true, 30, 0, "Welcome to TakaoOS!"));
    win.addWidget(TextWidget(false, true, 50, 0, "And to everyone in OSDev, yes, this is in ring 0"));
    win.addWidget(TextWidget(false, true, 55, 0, "Fight me"));
    win.addWidget(TextWidget(false, true, 70, 0, "Have a nice time around!"));
    win.addWidget(TextWidget(false, true, 85, 0, "Alt + n = New window"));
    win.addWidget(TextWidget(false, true, 90, 0, "Alt + d = Delete window"));

    debug log("Starting refresh cycle");
    for (;;) {
        mainWM.refresh();
    }

    panic("End of kernel");
}
