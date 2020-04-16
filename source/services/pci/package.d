module services.pci;

import lib.list;
import lib.bus;
import lib.messages;
import lib.alloc;
public import services.pci.pci;
import services.pci.scan;

struct PCIMessage {
    ubyte       deviceClass;
    ubyte       deviceSubclass;
    ubyte       deviceProgIF;
    PCIDevice** returnDevices;
}

__gshared MessageQueue!PCIMessage   pciQueue;
private __gshared List!(PCIDevice)* devices;

void pciService(void* unused) {
    log("Started PCI service");
    devices = scanPCI();
    printPCI(devices);

    while (true) {
        auto msg = pciQueue.receiveMessage();
        auto arr = msg.message.returnDevices;
        auto inx = 0;

        foreach (i; 0..devices.length) {
            if ((*devices)[i].deviceClass == msg.message.deviceClass    &&
                (*devices)[i].subclass    == msg.message.deviceSubclass &&
                (*devices)[i].progIf      == msg.message.deviceProgIF) {
                resizeArray!(PCIDevice)(arr, 1);
                (*arr)[inx++] = (*devices)[i];
            }
        }

        pciQueue.messageProcessed(msg);
    }
}
