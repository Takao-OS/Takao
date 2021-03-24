/// Window manager management functions and graphical environment goodies.
module display.wm;

import kernelprotocol:      KernelFramebuffer;
import display.framebuffer: Framebuffer;
import display.window:      Window;
import memory.alloc:        allocate, resizeAllocation;
import memory.physical:     PAGE_SIZE;
import lib.lock:            Lock;

private __gshared bool        isInit;
private __gshared Lock        wmLock;
private __gshared size_t      windows;
private __gshared Window*     windowList;
private __gshared Framebuffer backBuffer;
private __gshared Framebuffer frontBuffer;
private __gshared Framebuffer framebuffer;

private immutable loadingBackground = 0x0;
private immutable loadingFontColour = 0xffffff;
private immutable panicBackground   = 0xff0000;
private immutable panicFontColour   = 0xffffff;
private immutable wmBackground      = 0xaaaaaa;

/// Start window manager.
void initWM(KernelFramebuffer fb) {
    isInit = true;
    windows     = 0;
    windowList  = allocate!Window(0);
    backBuffer  = Framebuffer(fb.width, fb.height, fb.pitch);
    frontBuffer = Framebuffer(fb.width, fb.height, fb.pitch);
    framebuffer = Framebuffer(fb);
    backBuffer.clear(0x0);
    frontBuffer.clear(0x0);
    framebuffer.clear(0x0);
}

/// Display loading screen straight to the framebuffer, no double buffering.
void loadingScreen() {
    if (isInit) {
        framebuffer.clear(0x0);
        framebuffer.drawString(10, 10, "Loading...", loadingFontColour, loadingBackground);
    }
}

/// Show a panic screen, along with some information, straight to framebuffer.
void panicScreen(string message) {
    import display.font: fh = fontHeight;

    if (isInit) {
        framebuffer.clear(panicBackground);
        framebuffer.drawString(10, 10,          "PANIC:",                       panicFontColour, panicBackground);
        framebuffer.drawString(10, 10 + fh,     message,                        panicFontColour, panicBackground);
        framebuffer.drawString(10, 10 + fh * 2, "All data has been saved",      panicFontColour, panicBackground);
        framebuffer.drawString(10, 10 + fh * 3, "Feel free to restart your PC", panicFontColour, panicBackground);
    }
}

/// Add window.
void addWindow(Window win) {
    wmLock.acquire();
    resizeAllocation(&windowList, 1);
    windowList[windows++] = win;
    wmLock.release();
}

/// Pop window.
void popWindow(size_t index) {
    wmLock.acquire();
    if (index >= windows) {
        return;
    }

    foreach (i; (index + 1)..windows) {
        windowList[i - 1] = windowList[i];
    }
    windows--;
    resizeAllocation(&windowList, -1);
    wmLock.release();
}

/// Refresh the screen, showing all the window changes.
void refresh() {
    import display.cursor: drawCursor;

    // Draw everything.
    backBuffer.clear(wmBackground);
    foreach (i; 0..windows) {
        windowList[i].draw(&backBuffer);
    }
    drawCursor(&backBuffer);

    // Compare back and front buffer, and just write the changes.
    const size_t fbSize = backBuffer.rawsize();
    foreach (i; 0..fbSize) {
        if (backBuffer.contents[i] != frontBuffer.contents[i]) {
            framebuffer.contents[i] = backBuffer.contents[i];
        }
    }

    // Swap back and front buffer.
    auto temp   = backBuffer; // @suppress(dscanner.suspicious.unmodified)
    backBuffer  = frontBuffer;
    frontBuffer = temp;
}

/// Handler of keyboard input.
void wmKeyboardEntry(bool isAlt, char c) {
    if (isAlt) {
        switch (c) {
            case 'n':
                auto win = Window("New window", 300, 200);
                addWindow(win);
                break;
            case 'd':
                popWindow(0);
                break;
            default:
                break;
        }
    }
}

/// Handler of mouse input.
void wmMouseEntry(int xVariation, int yVariation, bool isLeftClick, bool isRightClick) {
    import display.cursor: updateCursor, getCursorPosition;

    size_t cursorX;
    size_t cursorY;
    getCursorPosition(cursorX, cursorY);
    updateCursor(xVariation, yVariation, backBuffer.getHeight, backBuffer.getWidth);

    if (isLeftClick) {
        foreach_reverse (i; 0..windows) {
            auto win = &windowList[i];
            if (win.isInWindow(cursorX, cursorY)) {
                auto temp = windowList[windows - 1]; // @suppress(dscanner.suspicious.unmodified)
                windowList[windows - 1] = windowList[i];
                windowList[i]           = temp;
                win = &windowList[windows - 1];
                win.setFocused(true);

                if (win.isTitleBar(cursorX, cursorY)) {
                    win.move(xVariation, yVariation);
                } else if (win.isInLeftBorders(cursorX, cursorY)) {
                    win.resize(xVariation, yVariation, false);
                } else if (win.isInRightBorders(cursorX, cursorY)) {
                    win.resize(xVariation, yVariation);
                } else {
                    win.putPixel(cursorX, cursorY, 0xffffff);
                }
                break;
            } else {
                win.setFocused(false);
            }
        }
    }
}
