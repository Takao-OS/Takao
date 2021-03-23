/// All the functions needed for driving the WM.
module wm.driver;

import stivale2:       Stivale2Framebuffer;
import wm.framebuffer: Framebuffer, createFramebuffer, clearFramebuffer, drawSimpleString;

private shared bool         isInit;
private shared Framebuffer* mainFramebuffer;

/// Initialize the window manager.
/// Params:
///     fb = Framebuffer to use for initializing the WM, never null.
void initWM(Stivale2Framebuffer* fb) {
    assert(fb != null);
    mainFramebuffer = cast(shared)createFramebuffer(fb);
    isInit          = true;
}

/// Print a loading screen for the WM.
void showLoadingScreen() {
    if (isInit) {
        auto fb = cast(Framebuffer*)mainFramebuffer;
        clearFramebuffer(fb, 0);
        drawSimpleString(fb, 0, 0, "Loading...", 0xffffff, 0);
    }
}

/// Print a panic screen in the WM.
/// Params:
///     msg = Message to use as reason for the panic, never null.
void showPanicScreen(string msg) {
    import wm.font: fontHeight;
    assert(msg != null);
    if (isInit) {
        auto fb = cast(Framebuffer*)mainFramebuffer;
        clearFramebuffer(fb, 0xff0000);
        drawSimpleString(fb, 0, 0, "PANIC:", 0xffffff, 0xff0000);
        drawSimpleString(fb, 0, fontHeight, msg, 0xffffff, 0xff0000);
    }
}
