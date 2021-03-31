/// Window manager management functions and graphical environment goodies.
module display.wm;

import kernelprotocol:      KernelFramebuffer;
import display.cursor:      Cursor;
import display.framebuffer: Framebuffer, Colour;
import display.window:      Window;
import memory.alloc:        allocate, resizeAllocation;
import lib.lock:            Lock;
import lib.list:            List;

private struct WindowPackage {
    bool   isPresent;
    int    wh;
    Window inner;
}

private immutable loadingBackground = 0x000000;
private immutable loadingFontColour = 0xffffff;
private immutable panicBackground   = 0xff0000;
private immutable panicFontColour   = 0xffffff;
private immutable wmBackground      = 0xaaaaaa;

private __gshared int windowMaxWH;

/// Window manager.
struct WM {
    private bool               isInit;
    private Lock               lock;
    private Framebuffer        backBuffer;
    private Framebuffer        frontBuffer;
    private Framebuffer        realBuffer;
    private Cursor             cursor;
    private List!WindowPackage windows;

    /// Create a WM for a physical framebuffer.
    this(const ref KernelFramebuffer fb) {
        backBuffer  = Framebuffer(fb.width, fb.height, fb.pitch);
        frontBuffer = Framebuffer(fb.width, fb.height, fb.pitch);
        realBuffer  = Framebuffer(fb);
        cursor      = Cursor(fb.width / 2, fb.height / 2);
        windows     = List!WindowPackage(5);
        isInit      = true;
        lock.release();
    }

    /// Display the loading screen, or do nothing if not initialized.
    void loadingScreen() {
        lock.acquire();
        realBuffer.clear(0x0);
        realBuffer.drawString(10, 10, "Loading...", loadingFontColour, loadingBackground);
        lock.release();
    }

    /// Display a panic screen, always prints, regardless of locks.
    /// Params:
    ///     message = Message to print, never null.
    void panicScreen(string message) {
        import display.font: fh = fontHeight;
        assert(message != null);
        if (!isInit) {
            return;
        }
        realBuffer.clear(panicBackground);
        realBuffer.drawString(10, 10,          "PANIC:",                       panicFontColour, panicBackground);
        realBuffer.drawString(10, 10 + fh,     message,                        panicFontColour, panicBackground);
        realBuffer.drawString(10, 10 + fh * 2, "All data has been saved",      panicFontColour, panicBackground);
        realBuffer.drawString(10, 10 + fh * 3, "Feel free to restart your PC", panicFontColour, panicBackground);
    }

    /// Create a window.
    /// Params:
    ///     name = Name of the window, null if none.
    /// Returns: Window handle number if successful, -1 in failure.
    int createWindow(string name) {
        lock.acquire();
        auto wh  = windowMaxWH++;
        auto win = Window(name, 300, 300);
        foreach (i; 0..windows.length) {
            if (!windows[i].isPresent) {
                windows[i].isPresent = true;
                windows[i].wh        = wh;
                windows[i].inner     = win;
                goto done;
            }
        }
        windows.push(WindowPackage(true, wh, win));
    done:
        lock.release();
        return wh;
    }

    /// Remove a window.
    /// Params:
    ///     window = Window to remove, never -1.
    void removeWindow(int window) {
        assert(window != -1);
        lock.acquire();
        foreach (i; 0..windows.length) {
            if (!windows[i].isPresent && windows[i].wh == window) {
                windows[i].isPresent = false;
                goto ret;
            }
        }
    ret:
        lock.release();
    }

    /// Refresh the WM.
    void refresh() {
        // Draw everything.
        backBuffer.clear(wmBackground);
        foreach_reverse (i; 0..windows.length) {
            if (windows[i].isPresent) {
                windows[i].inner.draw(&backBuffer);
            }
        }
        cursor.draw(backBuffer);

        // Compare back and front buffer, and just write the changes.
        const fbSize = backBuffer.size / Colour.sizeof;
        foreach (i; 0..fbSize) {
            if (backBuffer.address[i] != frontBuffer.address[i]) {
                realBuffer.address[i] = backBuffer.address[i];
            }
        }

        // Swap back and front buffer.
        auto temp   = backBuffer; // @suppress(dscanner.suspicious.unmodified)
        backBuffer  = frontBuffer;
        frontBuffer = temp;
    }

    /// Called to act on keyboard input.
    void keyboardEvent(bool isAlt, char c) {
        if (isAlt) {
            switch (c) {
                case 'n': createWindow("New window"); break;
                case 'd': removeWindow(0);            break;
                default:                              break;
            }
        }
    }

    /// Called to act on mouse input.
    void mouseEvent(int xVariation, int yVariation, bool isLeftClick, bool isRightClick) {
        size_t cursorX = cursor.cursorX;
        size_t cursorY = cursor.cursorY;
        cursor.update(xVariation, yVariation, backBuffer.height, backBuffer.width);

        if (isLeftClick) {
            foreach (i; 0..windows.length) {
                auto win = &windows[i];
                if (win.inner.isInWindow(cursorX, cursorY)) {
                    auto temp  = windows[0]; // @suppress(dscanner.suspicious.unmodified)
                    windows[0] = *win;
                    windows[i] = temp;
                    windows[0].inner.setFocused(true);
                    auto w = &windows[0].inner; 
                    if (w.isTitleBar(cursorX, cursorY)) {
                        w.move(xVariation, yVariation);
                    } else if (w.isInLeftBorders(cursorX, cursorY)) {
                        w.resize(xVariation, yVariation, false);
                    } else if (w.isInRightBorders(cursorX, cursorY)) {
                        w.resize(xVariation, yVariation);
                    } else {
                        w.putPixel(cursorX, cursorY, 0xffffff);
                    }
                    break;
                } else {
                    win.inner.setFocused(false);
                }
            }
        }
    }
}
