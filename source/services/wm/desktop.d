module services.wm.desktop;

import services.wm.framebuffer;
import lib.alloc;
import lib.stivale;
import lib.debugging;

private immutable PANEL_COLOUR      = 0xFFFFFF;
private immutable BACKGROUND_COLOUR = 0x008080;

struct Desktop {
    private Framebuffer* fb;

    this(StivaleFramebuffer stfb) {
        this.fb = newObj!Framebuffer(stfb);
    }

    void mainLoop() {
        while (true) {
            this.fb.clear(BACKGROUND_COLOUR);
        }
    }

    ~this() {
        delObj(this.fb);
    }
}
