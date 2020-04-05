module services.wm;

import stivale;
import lib.gc;
import services.wm.desktop;

void wmService(StivaleFramebuffer* fb) {
    auto desktop = newObj(Desktop(*fb));
    desktop.mainLoop();
}
