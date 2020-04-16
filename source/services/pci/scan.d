module services.pci.scan;

import lib.list;
import lib.alloc;
import lib.messages;
import services.pci.pci;

private immutable maxFunction = 8;
private immutable maxDevice   = 32;
private immutable maxBus      = 256;

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

List!(PCIDevice)* scanPCI() {
    auto scan    = newObj!(List!(PCIDevice))(5);
    auto rootBus = PCIDevice(0, 0, 0, 0);
    uint configC = rootBus.readDword(0xc);

    if (!(configC & 0x800000)) {
        checkBus(scan, 0, -1);
    } else {
        foreach (ubyte func; 0..maxFunction) {
            auto hostBridge = PCIDevice(0, 0, func, 0);
            auto config0    = hostBridge.readDword(0);
            if (config0 == 0xffffffff) {
                continue;
            }

            checkBus(scan, func, -1);
        }
    }

    return scan;
}

void printPCI(List!(PCIDevice)* scan) {
    log("PCI scan:");

    foreach (i; 0..scan.length) {
        auto dev = (*scan)[i];
        log("bus: ", dev.bus, " device: ", dev.device, " function: ", dev.func,
            " vendor id: ", dev.vendorId, " device id: ", dev.deviceId);

        log("bars: ");
        foreach (j; 0..5) {
            if (dev.barPresent(j)) {
                auto bar = dev.getBar(j);
                log("bar ", j, " base: ", bar.base, " len: ", bar.size);
            }
        }
    }
}
