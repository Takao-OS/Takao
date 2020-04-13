module services.pci;

import lib.bus;
import lib.messages;
import services.pci.pci;

void pciService(void* unused) {
    log("Started PCI service");
    initPCI();

    while (true) {
        continue;
    }
}
