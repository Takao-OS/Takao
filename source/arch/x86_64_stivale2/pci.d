/// Utilities for finding, discovering, reading, and writting to
/// PCI devices.
module arch.x86_64_stivale2.pci;

import arch.x86_64_stivale2.cpu: outb, inb, outd, inw, ind, outw;

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
        if (!(readDword(0x4) & (1 << 2))) {
            writeDword(0x04, readDword(0x4) | (1 << 2));
        }
    }

    private void getAddress(uint offset) {
        uint address = (bus << 16) | (device << 11) | (func << 8)
            | (offset & ~(cast(uint)(3))) | 0x80000000;
        outd(0xcf8, address);
    }
}
private immutable maxFunction = 8;
private immutable maxDevice   = 32;
private immutable maxBus      = 256;

import lib.list;

private void checkFunction(List!(PCIDevice)* scan, ubyte bus, ubyte slot,
                           ubyte func, long parent) {
    auto device = PCIDevice(bus, slot, func, parent);
    if (device.deviceId == 0xffff && device.vendorId == 0xffff) {
        return;
    }

    size_t id = scan.push(device);

    // PCI to PCI bridge, so we find devices attached to the bridge.
    if (device.deviceClass == 0x06 && device.subclass == 0x04) {
        auto bridgeDevice = (*scan)[id];
        auto config18     = bridgeDevice.readDword(0x18);
        checkBus(scan, (config18 >> 8) & 0xFF, id);
    }
}

private void checkBus(List!(PCIDevice)* scan, ubyte bus, long parent) {
    foreach (ubyte dev; 0..maxDevice) {
        foreach (ubyte func; 0..maxFunction) {
            checkFunction(scan, bus, dev, func, parent);
        }
    }
}

List!(PCIDevice) scanPCI() {
    auto scan    = List!(PCIDevice)(5);
    auto rootBus = PCIDevice(0, 0, 0, 0);
    uint configC = rootBus.readDword(0xc);

    if (!(configC & 0x800000)) {
        checkBus(&scan, 0, -1);
    } else {
        foreach (ubyte func; 0..maxFunction) {
            auto hostBridge = PCIDevice(0, 0, func, 0);
            auto config0    = hostBridge.readDword(0);
            if (config0 == 0xffffffff) {
                continue;
            }

            checkBus(&scan, func, -1);
        }
    }

    return scan;
}
