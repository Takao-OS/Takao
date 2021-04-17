/// Scan for devices and stuff.
module arch.x86_64_stivale2.devices;

import arch.x86_64_stivale2.pci: scanPCI, PCIDevice;
import kernelprotocol:           KernelDeviceMap, KernelDevice;

// TODO: This being fixed could be an issue.
private shared KernelDevice[20] privateDevices;

/// Scan the devices in the system and return them in the kernel protocol
/// form.
KernelDeviceMap scanDevices() {
    // Add the strictly necessary devices.
    size_t deviceCount = 1;
    privateDevices[0] = KernelDevice("x86-ps2-controller", [0, 0, 0, 0]);

    // Translate PCI into the device list.
    auto devs = scanPCI();
    foreach (i; 0..devs.length) {
        if (deviceCount >= privateDevices.length) {
            break;
        }
        auto dev = &devs[i];
        if (dev.deviceClass == 0x01 && dev.subclass == 0x08 && dev.progIf == 0x02) {
            const bar0 = dev.getBar(0);
            dev.writeDword(0x4, dev.readDword(0x4) | (1 << 1)); // Enable MMIO.
            dev.enableBusMastering();
            privateDevices[deviceCount].driver   = "nvme-controller";
            privateDevices[deviceCount].mmioRegs = [bar0.base, 0, 0, 0];
            deviceCount++;
        } else if (dev.deviceClass == 0x01 && dev.subclass == 0x01) {
            dev.enableBusMastering();
            privateDevices[deviceCount].driver   = "ata-controller";
            privateDevices[deviceCount].mmioRegs = [0, 0, 0, 0];
            deviceCount++;
        } else if (dev.deviceClass == 0x01 && dev.subclass == 0x06 && dev.progIf == 0x01) {
            const bar0 = dev.getBar(5);
            dev.enableBusMastering();
            privateDevices[deviceCount].driver   = "sata-controller";
            privateDevices[deviceCount].mmioRegs = [bar0.base, 0, 0, 0];
            deviceCount++;
        }
    }

    // Return our findings.
    return KernelDeviceMap(deviceCount, cast(KernelDevice*)privateDevices.ptr);
}
