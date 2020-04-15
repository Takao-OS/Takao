module services.storage;

import lib.alloc;
import lib.messages;
import services.pci;

immutable pciNVMEClass    = 0x01;
immutable pciNVMESubclass = 0x08;
immutable pciNVMEProgIF   = 0x02;

void storageService(void* unused) {
    log("Started Storage service");
    auto arr = newArray!(PCIDevice)(0);
    auto msg = PCIMessage(pciNVMEClass, pciNVMESubclass, pciNVMEProgIF, &arr);
    pciQueue.sendMessageSync(msg);

    log("Found ", getArraySize(arr), " NVME drives");

    while (true) {
        continue;
    }
}
