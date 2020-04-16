module services.pci.pci;

import system.cpu;

struct PCIBar {
    size_t base;
    size_t size;
    bool   isMmio;
    bool   isPrefetchable;
}

struct PCIDevice {
    long   parent;
    ubyte  bus;
    ubyte  func;
    ubyte  device;
    ushort deviceId;
    ushort vendorId;
    ubyte  revId;
    ubyte  subclass;
    ubyte  deviceClass;
    ubyte  progIf;
    bool   multifunction;
    ubyte  irqPin;

    this(ubyte bus, ubyte slot, ubyte func, long parent) {
        this.parent = parent;
        this.bus    = bus;
        this.func   = func;
        this.device = slot;

        auto config0  = readDword(0);
        auto config8  = readDword(0x8);
        auto configc  = readDword(0xc);
        auto config3c = readDword(0x3c);

        deviceId      = cast(ushort)(config0 >> 16);
        vendorId      = cast(ushort)config0;
        revId         = cast(ubyte)config8;
        subclass      = cast(ubyte)(config8 >> 16);
        deviceClass   = cast(ubyte)(config8 >> 24);
        progIf        = cast(ubyte)(config8 >> 8);
        multifunction = configc & 0x800000 ? true : false;
        irqPin        = cast(ubyte)(config3c >> 8);
    }

    ubyte readByte(uint offset) {
        getAddress(offset);
        return inb(0xcfc + (offset & 3));
    }

    void writeByte(uint offset, ubyte value) {
        getAddress(offset);
        outb(0xcfc + (offset & 3), value);
    }

    ushort readWord(uint offset) {
        assert(!(offset & 1));
        getAddress(offset);
        return inw(0xcfc + (offset & 3));
    }

    void writeWord(uint offset, ushort value) {
        assert(!(offset & 1));
        getAddress(offset);
        outw(0xcfc + (offset & 3), value);
    }

    uint readDword(uint offset) {
        assert(!(offset & 3));
        getAddress(offset);
        return ind(0xcfc + (offset & 3));
    }

    void writeDword(uint offset, uint value) {
        assert(!(offset & 3));
        getAddress(offset);
        outd(0xcfc + (offset & 3), value);
    }

    bool barPresent(int bar) {
        assert(bar <= 5);
        auto regIndex = 0x10 + bar * 4;
        return readDword(regIndex) ? true : false;
    }

    PCIBar getBar(int bar) {
        assert(bar <= 5);

        auto regIndex      = 0x10 + bar * 4;
        auto barLow        = readDword(regIndex);
        auto barSizeLow    = readDword(regIndex);
        auto barHigh       = 0;
        size_t barSizeHigh = 0;

        bool isMmio         = !(barLow & 1);
        bool isPrefetchable = isMmio && barLow & (1 << 3);
        bool is64bit        = isMmio && ((barLow >> 1) & 0b11) == 0b10;

        if (is64bit) {
            barHigh = readDword(regIndex + 4);
        }

        size_t base = ((cast(ulong)barHigh << 32) | barLow) & ~(isMmio ? (0b1111) : (0b11));

        writeDword(regIndex, 0xFFFFFFFF);
        barSizeLow = readDword(regIndex);
        writeDword(regIndex, barLow);

        if (is64bit) {
            writeDword(regIndex + 4, 0xFFFFFFFF);
            barSizeHigh = readDword(regIndex + 4);
            writeDword(regIndex + 4, barHigh);
        } else {
            barSizeHigh = 0xFFFFFFFF;
        }

        size_t size = ((barSizeHigh << 32) | barSizeLow) & ~(isMmio ? 0b1111 : 0b11);
        size = ~size + 1;

        return PCIBar(base, size, isMmio, isPrefetchable);
    }

    void enableBusMastering() {
        if (readDword(0x4) & (1 << 2)) {
            writeDword(0x04, readDword(0x4) | (1 << 2));
        }
    }

    private void getAddress(uint offset) {
        uint address = (bus << 16) | (device << 11) | (func << 8)
            | (offset & ~(cast(uint)(3))) | 0x80000000;
        outd(0xcf8, address);
    }
}
