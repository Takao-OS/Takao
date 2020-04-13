module services.pci.pci;

import system.cpu;
import lib.list;
import lib.alloc;
import services.kmessage;
import services.terminal;
import lib.messages;

private immutable uint MAX_FUNCTION = 8;
private immutable uint MAX_DEVICE = 32;
private immutable uint MAX_BUS = 256;


struct PciBar {
    size_t base;
    size_t size;

    int isMmio;
    int isPrefetchable;
}

struct PciDevice {
    long parent;

    ubyte bus;
    ubyte func;
    ubyte device;
    ushort deviceId;
    ushort vendorId;
    ubyte revId;
    ubyte subclass;
    ubyte deviceClass;
    ubyte progIf;
    int multifunction;
    ubyte irqPin;

    private void getAddress(uint offset) {
        uint address = (this.bus << 16) | (this.device << 11) | (this.func << 8)
            | (offset & ~(cast(uint)(3))) | 0x80000000;
        outd(0xcf8, address);
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
        PciBar ret;
        assert(bar <= 5);

        uint regIndex = 0x10 + bar * 4;
        uint barLow = this.readDword(regIndex);
        ulong barSizeLow;
        uint barHigh = 0;
        ulong barSizeHigh = 0;

        if (!barLow)
            return false;
        return true;
    }

    PciBar getBar(int bar) {
        PciBar ret;
        assert(bar <= 5);

        uint regIndex = 0x10 + bar * 4;
        uint barLow = this.readDword(regIndex);
        ulong barSizeLow;
        uint barHigh = 0;
        ulong barSizeHigh = 0;

        ret.isMmio = !(barLow & 1);
        int isPrefetchable = ret.isMmio && barLow & (1 << 3);
        int is64bit = ret.isMmio && ((barLow >> 1) & 0b11) == 0b10;

        if (is64bit)
            barHigh = this.readDword(regIndex + 4);

        ret.base = ((cast(ulong)barHigh << 32) | barLow) & ~(ret.isMmio ? (0b1111) : (0b11));

        this.writeDword(regIndex, 0xFFFFFFFF);
        barSizeLow = cast(ulong)this.readDword(regIndex);
        this.writeDword(regIndex, barLow);

        if (is64bit) {
            this.writeDword(regIndex + 4, 0xFFFFFFFF);
            barSizeHigh = cast(ulong)this.readDword(regIndex + 4);
            this.writeDword(regIndex + 4, barHigh);
        } else {
            barSizeHigh = 0xFFFFFFFF;
        }

        size_t size = ((barSizeHigh << 32) | barSizeLow) & ~(ret.isMmio ? (0b1111) : (0b11));
        size = ~size + 1;
        ret.size = size;

        return ret;
    }
}

private __gshared List!PciDevice pciDevices;
private __gshared size_t numDevices;

static void pciCheckFunction(ubyte bus, ubyte slot, ubyte func, long parent) {
    PciDevice device = {0};
    device.bus = bus;
    device.func = func;
    device.device = slot;

    uint config0 = device.readDword(0);

    if (config0 == 0xffffffff) {
        return;
    }

    uint config8 = device.readDword(0x8);
    uint configc = device.readDword(0xc);
    uint config3c = device.readDword(0x3c);

    device.parent = parent;
    device.deviceId = cast(ushort)(config0 >> 16);
    device.vendorId = cast(ushort)config0;
    device.revId = cast(ubyte)config8;
    device.subclass = cast(ubyte)(config8 >> 16);
    device.deviceClass = cast(ubyte)(config8 >> 24);
    device.progIf = cast(ubyte)(config8 >> 8);
    device.irqPin = cast(ubyte)(config3c >> 8);

    if (configc & 0x800000)
        device.multifunction = 1;
    else
        device.multifunction = 0;

    size_t id = pciDevices.push(device);
    numDevices++;

    if (device.deviceClass == 0x06 && device.subclass == 0x04) {
        // pci to pci bridge
        PciDevice bridgeDevice = pciDevices[id];

        // find devices attached to this bridge
        uint config18 = bridgeDevice.readDword(0x18);
        pciCheckBus((config18 >> 8) & 0xFF, id);
    }
}

static void pciCheckBus(ubyte bus, long parent) {
    for (ubyte dev = 0; dev < MAX_DEVICE; dev++) {
        for (ubyte func = 0; func < MAX_FUNCTION; func++) {
            pciCheckFunction(bus, dev, func, parent);
        }
    }
}

void pciScan() {
    PciDevice newDev;
    uint configC = newDev.readDword(0xc);
    uint config0;

    if (!(configC & 0x800000)) {
        pciCheckBus(0, -1);
    } else {
        for (ubyte func = 0; func < 8; func++) {
            newDev.func = func;
            config0 = newDev.readDword(0);

            if (config0 == 0xffffffff)
                continue;
            pciCheckBus(func, -1);
        }
    }
}

void initPCI() {
    log("pci: starting scan");
    pciDevices = List!PciDevice(1);
    pciScan();
    pciDevices.shrinkToFit();

    for (int i = 0; i < numDevices; i++) {
        PciDevice dev = pciDevices[i];
        log("bus: ", dev.bus, " device: ", dev.device, " function: ", dev.func, " vendor id: ", dev.vendorId, " device id: ", dev.deviceId);
        log("bars: ");
        for (int j = 0; j < 5; j++) {
            if (dev.barPresent(j)) {
                auto bar = dev.getBar(j);
                log("bar ", j, " base: ", bar.base, " len: ", bar.size);
            }
        }
    }
}
