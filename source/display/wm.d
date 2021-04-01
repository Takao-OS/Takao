/// Window manager management functions and graphical environment goodies.
module display.wm;

import kernelprotocol:      KernelFramebuffer;
import display.cursor:      Cursor;
import display.framebuffer: Framebuffer, Colour;
import display.window:      Window;
import display.fonts:       PSFont;
import display.defaultfont: fontHeight, fontWidth, getFontCharacter;
import memory.virtual:      pageSize, MapType;
import lib.math:            divRoundUp;
import lib.lock:            Lock;
import lib.list:            List;
import main:                mainMappings;

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
    private bool               hasBold;
    private PSFont             boldFont;
    private bool               hasCursive;
    private PSFont             cursiveFont;
    private bool               hasSans;
    private PSFont             sansFont;

    /// Create a WM for a physical framebuffer.
    this(const ref KernelFramebuffer fb) {
        backBuffer  = Framebuffer(fb.width, fb.height, fb.pitch);
        frontBuffer = Framebuffer(fb.width, fb.height, fb.pitch);
        realBuffer  = Framebuffer(fb);

        // Map the framebuffer.
        const fbPages = divRoundUp(fb.height * fb.pitch, pageSize);
        foreach (i; 0..fbPages) {
            const pageAddress = fb.address + (i * pageSize);
            mainMappings.mapPage(pageAddress, pageAddress, MapType.Supervisor | MapType.WriteCombine);
        }

        cursor     = Cursor(fb.width / 2, fb.height / 2);
        windows    = List!WindowPackage(5);
        hasBold    = false;
        hasCursive = false;
        hasSans    = false;
        isInit     = true;
        lock.release();
    }

    /// Load a bold font.
    bool loadBoldFont(string path) {
        assert(path != null);
        boldFont = PSFont(path, hasBold);
        return hasBold;
    }

    /// Load a cursive font.
    bool loadCursiveFont(string path) {
        assert(path != null);
        cursiveFont = PSFont(path, hasCursive);
        return hasCursive;
    }

    /// Load a sans font.
    bool loadSansFont(string path) {
        assert(path != null);
        sansFont = PSFont(path, hasSans);
        return hasSans;
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
        import display.defaultfont: fh = fontHeight;
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

    /// Fetch window for modifying.
    /// Params:
    ///     window = Window handle.
    /// Returns: Window pointer or null if not found.
    Window* fetchWindow(int window) {
        assert(window != -1);

        Window* ret = null;
        foreach (i; 0..windows.length) {
            if (windows[i].isPresent && windows[i].wh == window) {
                ret = &windows[i].inner;
                goto end;
            }
        }

    end:
        lock.release();
        return ret;
    }

    /// Remove a window.
    /// Params:
    ///     window = Window to remove, never -1.
    void removeWindow(int window) {
        assert(window != -1);
        lock.acquire();
        foreach (i; 0..windows.length) {
            if (windows[i].isPresent && windows[i].wh == window) {
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
        auto bold = hasBold    ? &boldFont    : null;
        auto curs = hasCursive ? &cursiveFont : null;
        auto sans = hasSans    ? &sansFont    : null;

        backBuffer.clear(wmBackground);
        foreach_reverse (i; 0..windows.length) {
            if (windows[i].isPresent) {
                windows[i].inner.draw(bold, curs, sans, backBuffer);
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
                case 'n':
                    createWindow("New window");
                    break;
                case 'd':
                    foreach (i; 0..windows.length) {
                        if (windows[i].isPresent) {
                            windows[i].isPresent = false;
                            break;
                        }
                    }
                    break;
                default:
                    break;
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
                    }
                    break;
                } else {
                    win.inner.setFocused(false);
                }
            }
        }
    }
}
