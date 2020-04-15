module services.pci;

import lib.bus;
import lib.messages;
import lib.alloc;
public import services.pci.pci;

struct PCIMessage {
    ubyte       deviceClass;
    ubyte       deviceSubclass;
    ubyte       deviceProgIF;
    PCIDevice** returnDevices;
}

__gshared MessageQueue!PCIMessage pciQueue;

void pciService(void* unused) {
    log("Started PCI service");
    initPCI();

    while (true) {
        auto msg = pciQueue.receiveMessage();
        auto arr = msg.message.returnDevices;
        auto inx = 0;

        foreach (i; 0..pciDevices.length) {
            if ((*pciDevices)[i].deviceClass == msg.message.deviceClass    &&
                (*pciDevices)[i].subclass    == msg.message.deviceSubclass &&
                (*pciDevices)[i].progIf      == msg.message.deviceProgIF) {
                resizeArray!(PCIDevice)(arr, 1);
                (*arr)[inx++] = (*pciDevices)[i];
            }
        }

        pciQueue.messageProcessed(msg);
    }
}
