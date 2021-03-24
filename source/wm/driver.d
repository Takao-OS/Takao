/// All the functions needed for driving the WM.
module wm.driver;

import stivale2:       Stivale2Framebuffer;
import wm.framebuffer: Framebuffer, createFramebuffer, clearFramebuffer, drawSimpleString;

private immutable loadingBackground = 0x742f5e;
private immutable loadingForeground = 0xffffff;
private immutable panicBackground   = 0x04048b;
private immutable panicForeground   = 0xffffff;

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
        clearFramebuffer(fb, loadingBackground);
        drawSimpleString(fb, 0, 0, "Loading...", loadingForeground, loadingBackground);
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
        clearFramebuffer(fb, panicBackground);
        drawSimpleString(fb, 0, 0, "PANIC:", panicForeground, panicBackground);
        drawSimpleString(fb, 0, fontHeight, msg, panicForeground, panicBackground);
    }
}
