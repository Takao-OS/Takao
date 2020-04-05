module services.wm;

import lib.stivale;
import lib.gc;
import services.wm.desktop;
import lib.bus;
import services.kmessage;

void wmService(StivaleFramebuffer* fb) {
    auto desktop  = newObj(Desktop(*fb));
    auto kmessage = getMessageQueue!KMessage(KMESSAGE_SERVICE_NAME);

    kmessage.sendMessage(KMessage(KMessagePriority.Log, "Started WM service"));
    desktop.mainLoop();
}
