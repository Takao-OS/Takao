/// Protocol passed to the kernel when booting the freestanding part.
module kernelprotocol;

debug import lib.debugtools: log;

/// Struct containing the protocol used to call the kernel.
struct KernelProtocol {
    string            cmdline; /// Commandline used to call the kernel.
    KernelFramebuffer fb;      /// Framebuffer, for use if there is no GPU.
    KernelMemoryMap   mmap;    /// Memory map passed to the kernel.
    KernelDeviceMap   devices; /// Devices to be used by the kernel.

    /// Print the struct contents to debug output.
    debug void debugPrint() {
        log("Command line: '", cmdline, "'");
        log("Framebuffer:");
        fb.debugPrint();
        log("Memory map:");
        mmap.debugPrint();
        log("Device map:");
        devices.debugPrint();
    }
}

/// Framebuffer information passed to the kernel.
struct KernelFramebuffer {
    size_t address; /// Physical address of the framebuffer.
    ushort width;   /// Width of the framebuffer in pixels.
    ushort height;  /// Height in pixels.
    ulong  pitch;   /// Pitch in bytes.
    ushort bpp;     /// Bytes per pixel.

    /// Print the struct contents to debug output.
    debug void debugPrint() {
        log("Address: ", cast(void*)address);
        log("Width:   ", width);
        log("Height:  ", height);
        log("Pitch:   ", pitch);
        log("Bpp:     ", bpp);
    }
}

/// Struct containing the kernel memory map.
/// All entries are free, and do not require being contiguous or aligned to
/// any boundary.
struct KernelMemoryMap {
    size_t             entryCount; /// Count of entries.
    KernelMemoryEntry* entries;    /// Actual entries.

    /// Print the struct contents to debug output.
    debug void debugPrint() {
        foreach (i; 0..entryCount) {
            entries[i].debugPrint();
        }
    }
}

/// Memory entry.
struct KernelMemoryEntry {
    size_t base;   /// Base of the memory range.
    size_t size;   /// Size of the memory range.
    bool   isFree; /// Whether the entry is free or not.

    /// Print the struct contents to debug output.
    debug void debugPrint() {
        log("[", cast(void*)base, " + ", cast(void*)size, "] - ", cast(size_t)isFree);
    }
}

/// Struct containing uninitialized device information.
struct KernelDeviceMap {
    size_t        deviceCount; /// Device count.
    KernelDevice* devices;     /// Actual devices.

    /// Print the struct contents to debug output.
    debug void debugPrint() {
        foreach (i; 0..deviceCount) {
            devices[i].debugPrint();
        }
    }
}

/// Information of a device.
struct KernelDevice {
    string    driver;   /// Name of the driver that implements it.
    size_t[4] mmioRegs; /// Addresses to be used by the driver, take this as arguments.

    /// Print the struct contents to debug output.
    debug void debugPrint() {
        log("'", driver, "' using addresses:");
        foreach (i; mmioRegs) {
            log(i);
        }
    }
}
