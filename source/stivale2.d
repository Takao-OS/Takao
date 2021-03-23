/// Stivale2 information fetching and parsing.
module stivale2;

/// Main struct of the stivale2 protocol, its whats passed to the kernel and
/// where we start our parsing and info recollecting.
struct Stivale2 {
    align(1):
    char[64] bootloaderBrand;   /// C-style string for the bootloader name.
    char[64] bootloaderVersion; /// C-style string for the version.
    ulong    tags;              /// Start of the tags.
}

/// Base tag for them all.
struct Stivale2Tag {
    align(1):
    ulong identifier; /// 64 bit identifier for the tag.
    ulong next;       /// Next in line, or 0 if none.
}

/// Tag for the commandline.
struct Stivale2CMDLine {
    align(1):
    Stivale2Tag header;  /// Header of the tag.
    ulong       cmdline; /// Address of the commandline.
}

/// Tag for the framebuffer information.
struct Stivale2Framebuffer {
    align(1):
    Stivale2Tag header;         /// Header of the tag.
    ulong       address;        /// Physical address of the buffer.
    ushort      width;          /// Width of the buffer in pixels.
    ushort      height;         /// Height of the buffer in pixels.
    ushort      pitch;          /// Pitch of the buffer in bytes.
    ushort      bpp;            /// Bits per pixel
    ubyte       memoryModel;    /// 1 for RGB.
    ubyte       redMaskSize;    /// Size of the red mask in bits.
    ubyte       redMaskShift;   /// Shift of the red mask.
    ubyte       greenMaskSize;  /// Size of the green mask in bits.
    ubyte       greenMaskShift; /// Shift of the green mask.
    ubyte       blueMaskSize;   /// Size of the blue mask in bits.
    ubyte       blueMaskShift;  /// Shift of the blue mask.
}

/// Tag for the RSDP.
struct Stivale2RSDP {
    align(1):
    Stivale2Tag header; /// Header of the tag.
    ulong       rsdp;   /// Physical address of the RSDP.
}

/// Tag for the memory map.
struct Stivale2MemoryMap {
    align(1):
    Stivale2Tag         header;  /// Header of the tag.
    ulong               entries; /// Count of entries.
    Stivale2MemoryEntry memmap;  /// Beggining of the entries (D doesnt have varlength arrays).
}

/// A Memory map entry.
struct Stivale2MemoryEntry {
    ulong base;   /// Start of the represented memory range.
    ulong length; /// Length of the range.
    uint  type;   /// Type of the entry.
    uint  unused; /// Unused field.
}

/// Types of memory map entries.
enum Stivale2MemoryType : uint {
    Usable                = 1,
    Reserved              = 2,
    ACPIReclaimable       = 3,
    ACPINVS               = 4,
    BadMemory             = 5,
    BootloaderReclaimable = 0x1000,
    KernelAndModules      = 0x1001
}

/// Retrieve a tag from stivale2.
/// Params:
///     proto = Protocol pointer, never null.
/// Returns: A pointer to the requested tag, or null if not found.
T* getStivale2Tag(T : Stivale2CMDLine)(Stivale2* proto) {
    assert(proto != null);
    return cast(Stivale2CMDLine*)getStivale2TagInner(proto, 0xE5E76A1B4597A781);
}

T* getStivale2Tag(T : Stivale2Framebuffer)(Stivale2* proto) {
    assert(proto != null);
    return cast(Stivale2Framebuffer*)getStivale2TagInner(proto, 0x506461D2950408FA);
}

T* getStivale2Tag(T : Stivale2RSDP)(Stivale2* proto) {
    assert(proto != null);
    return cast(Stivale2RSDP*)getStivale2TagInner(proto, 0x9E1786930A375E78);
}

T* getStivale2Tag(T : Stivale2MemoryMap)(Stivale2* proto) {
    assert(proto != null);
    return cast(Stivale2MemoryMap*)getStivale2TagInner(proto, 0x2187F79E8612dE07);
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
