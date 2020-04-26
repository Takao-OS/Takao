module stivale;

struct StivaleModule {
    ulong begin;
    ulong end;
    char[128] name;
}

struct StivaleMemmap {
    StivaleMemmapEntry* address;
    ulong               entries;
}

enum StivaleMemmapType : uint {
    Unusable    = 0,
    Usable      = 1,
    Reserved    = 2,
    ACPIReclaim = 3,
    ACPINVS     = 4
}

struct StivaleMemmapEntry {
    ulong base;
    ulong size;
    uint  type;
    uint  unused;
}

struct StivaleFramebuffer {
    ulong address;
    ushort pitch;
    ushort width;
    ushort height;
    ushort bpp;
}

struct Stivale {
    ulong cmdline;
    StivaleMemmap memmap;
    StivaleFramebuffer framebuffer;
    ulong rsdp;
    ulong moduleCount;
    StivaleModule[] modules;
}
