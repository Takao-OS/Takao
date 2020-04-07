module services.wm;

import lib.stivale;
import lib.alloc;
import services.wm.desktop;
import lib.bus;
import services.kmessage;

void wmService(StivaleFramebuffer* fb) {
    auto kmessage = getMessageQueue!KMessage(KMESSAGE_SERVICE_NAME);

    kmessage.sendMessage(KMessage(KMessagePriority.Log, "Started WM service"));

    auto desktop  = newObj!(Desktop)(*fb);
    desktop.mainLoop();
}
