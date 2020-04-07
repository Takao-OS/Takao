module services.wm;

import services.wm.desktop;
import lib.stivale;
import lib.alloc;
import lib.bus;
import lib.messages;

void wmService(StivaleFramebuffer* fb) {
    log("Started WM service");

    auto desktop = newObj!(Desktop)(*fb);
    desktop.mainLoop();
}
