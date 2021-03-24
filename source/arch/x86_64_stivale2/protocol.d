/// Stivale2 protocol.
/// All the info is taken and explained at https://github.com/stivale/stivale/blob/master/STIVALE2.md.
module arch.x86_64_stivale2.protocol;

debug import lib.string:     fromCString;
debug import lib.debugtools: log;

immutable stivale2CmdLineID     = 0xe5e76a1b4597a781; /// Cmdline tag ID.
immutable stivale2FramebufferID = 0x506461d2950408fa; /// Framebuffer tag ID.
immutable stivale2MemmapID      = 0x2187f79e8612de07; /// Memmap tag ID.
immutable stivale2RSDPID        = 0x9e1786930a375e78; /// RSDP tag id.
immutable stivale2SMPID         = 0x34d1d96339647025; /// SMP tag ID.

/// Stivale2 main struct passed to the kernel.
struct Stivale2 {
    align(1):
    char[64] bootloaderBrand;   /// Bootloader name.
    char[64] bootloaderVersion; /// Bootloader version.
    ulong    tags;              /// Start of the tags, or 0 for none.

    /// Debug print.
    debug void debugPrint() {
        alias b = bootloaderBrand, v = bootloaderVersion;
        log("Bootloader: ", fromCString(b.ptr, b.length));
        log("Version:    ", fromCString(v.ptr, v.length));
        log("Tag start:  ", cast(void*)tags);
    }
}

/// Base tag for all other tags.
struct Stivale2Tag {
    align(1):
    ulong identifier; /// Identifier of the tag.
    ulong next;       /// Next item on the list, or 0.

    /// Debug print.
    debug void debugPrint() {
        log("Identifier: ", cast(void*)identifier);
        log("Next:       ", cast(void*)next);
    }
}

/// Cmdline tag.
struct Stivale2Cmdline {
    align(1):
    Stivale2Tag tag;     /// Base tag.
    ulong       cmdline; /// Commandline address.

    /// Debug print.
    debug void debugPrint() {
        tag.debugPrint();
        log("Command line: ", fromCString(cast(char*)cmdline));
    }
}

/// Types of framebuffer memory model.
enum Stivale2FbModel : ubyte {
    RGB = 1
}

/// Framebuffer tag.
struct Stivale2Framebuffer {
    align(1):
    Stivale2Tag     tag;            /// Base tag.
    ulong           address;        /// Address of the framebuffer.
    ushort          width;          /// Width in pixels.
    ushort          height;         /// Height in pixels.
    ushort          pitch;          /// Pitch in bytes.
    ushort          bpp;            /// BPP.
    Stivale2FbModel memoryModel;    /// Memory model of the fb.
    ubyte           redMaskSize;    /// Red mask size.
    ubyte           redMaskShift;   /// Its shift.
    ubyte           greenMaskSize;  /// Green mask size.
    ubyte           greenMaskShift; /// Its shift.
    ubyte           blueMaskSize;   /// Blue mask size.
    ubyte           blueMaskShift;  /// Its shift.

    /// Debug print.
    debug void debugPrint() {
        tag.debugPrint();
        log("Address      ", cast(void*)address);
        log("Width:       ", width);
        log("Height:      ", height);
        log("Pitch:       ", pitch);
        log("BPP:         ", bpp);
        log("Model:       ", memoryModel);
        log("Red Size:    ", redMaskSize);
        log("Red Shift:   ", redMaskShift);
        log("Green Size:  ", greenMaskSize);
        log("Green Shift: ", greenMaskShift);
        log("Blue Size:   ", blueMaskSize);
        log("Blue Shift:  ", blueMaskShift);
    }
}

/// Memmap tag.
struct Stivale2Memmap {
    align(1):
    Stivale2Tag         tag;     /// Tag information.
    ulong               count;   /// Count of entries.
    Stivale2MemmapEntry entries; /// Array, its varlength.

    /// Debug print.
    debug void debugPrint() {
        auto ptr = &entries;
        tag.debugPrint();
        log("Entry count: ", count);
        foreach (i; 0..count) {
            ptr[i].debugPrint();
        }
    }
}

/// Memmap tag.
struct Stivale2MemmapEntry {
    align(1):
    ulong              base;   /// Tag information.
    ulong              length; /// Count of entries.
    Stivale2MemoryType type;   /// Type.
    uint               unused; /// Lol.

    /// Debug print.
    debug void debugPrint() {
        log("\tBase:   ", cast(void*)base);
        log("\tLength: ", cast(void*)length);
        log("\tType:   ", type);
    }
}

/// Type of memory entry.
enum Stivale2MemoryType : uint {
    Usable                = 1,
    Reserved              = 2,
    ACPIReclaimable       = 3,
    ACPINVS               = 4,
    BadMemory             = 5,
    BootloaderReclaimable = 0x1000,
    KernelAndModules      = 0x1001
}

/// RSDP tag.
struct Stivale2RSDP {
    Stivale2Tag tag;  /// Tag info.
    ulong       rsdp; /// RSDP address.

    /// Debug print.
    debug void debugPrint() {
        tag.debugPrint();
        log("RSDP: ", cast(void*)rsdp);
    }
}

/// SMP tag.
struct Stivale2SMP {
    align(1):
    Stivale2Tag      tag;        /// Tag information.
    ulong            flags;      /// Bit 0 is set if x2APIC is provided.
    uint             bspLAPICID; /// The LAPIC of the BSP.
    uint             unused;     /// Lol.
    ulong            cpuCount;   /// Total number of CPUs including BSP.
    Stivale2SMPEntry entries;    /// Array, its varlength.

    /// Debug print.
    debug void debugPrint() {
        auto ptr = &entries;
        tag.debugPrint();
        log("Flags:        ", flags);
        log("BSP LAPIC ID: ", bspLAPICID);
        log("CPU count:    ", cpuCount);
        foreach (i; 0..cpuCount) {
            ptr[i].debugPrint();
        }
    }
}

/// Memmap tag.
struct Stivale2SMPEntry {
    align(1):
    uint  acpiProcessorUID; /// UID as said by the MADT.
    uint  lapicID;          /// LAPIC ID as said by the MADT.
    ulong stack;            /// Stack loaded once gotoAddress is loaded.
    ulong gotoAddress;      /// Once loaded, core will execute this address.
    ulong argument;         /// An argument to pass to the core in RDI.

    /// Debug print.
    debug void debugPrint() {
        log("\tACPI Processor UID: ", acpiProcessorUID);
        log("\tLAPIC ID:           ", lapicID);
    }
}

/// Retrieve a tag from stivale2.
/// Params:
///     proto = Protocol pointer, never null.
/// Returns: A pointer to the requested tag, or null if not found.
T* getStivale2Tag(T : Stivale2Cmdline)(Stivale2* proto) {
    assert(proto != null);
    return cast(Stivale2Cmdline*)getStivale2TagInner(proto, stivale2CmdLineID);
}

T* getStivale2Tag(T : Stivale2Framebuffer)(Stivale2* proto) {
    assert(proto != null);
    return cast(Stivale2Framebuffer*)getStivale2TagInner(proto, stivale2FramebufferID);
}

T* getStivale2Tag(T : Stivale2Memmap)(Stivale2* proto) {
    assert(proto != null);
    return cast(Stivale2Memmap*)getStivale2TagInner(proto, stivale2MemmapID);
}

T* getStivale2Tag(T : Stivale2SMP)(Stivale2* proto) {
    assert(proto != null);
    return cast(Stivale2SMP*)getStivale2TagInner(proto, stivale2SMPID);
}

T* getStivale2Tag(T : Stivale2RSDP)(Stivale2* proto) {
    assert(proto != null);
    return cast(Stivale2RSDP*)getStivale2TagInner(proto, stivale2RSDPID);
}

private void* getStivale2TagInner(Stivale2* proto, ulong id) {
    assert(proto != null);

    auto search = cast(Stivale2Tag*)proto.tags;
    while (search != null) {
        if (search.identifier == id) {
            return search;
        }
        search = cast(Stivale2Tag*)search.next;
    }
    return null;
}
