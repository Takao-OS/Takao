module wm.desktop;

import lib.gc;
import services.wm.framebuffer;
import stivale;

private immutable PANEL_COLOUR      = 0xFFFFFF;
private immutable BACKGROUND_COLOUR = 0x008080;

struct Desktop {
    private Framebuffer* fb;

    this(StivaleFramebuffer stfb) {
        this.fb = newObj(Framebuffer(stfb));
    }

    void mainLoop() {
        while (true) {
            this.fb.clear(BACKGROUND_COLOUR);
        }
    }
}
