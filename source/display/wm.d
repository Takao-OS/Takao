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

private immutable loadingBackground = 0x000000;
private immutable loadingFontColour = 0xffffff;
private immutable panicBackground   = 0xff0000;
private immutable panicFontColour   = 0xffffff;
private immutable wmBackground      = 0xaaaaaa;

/// Window manager.
struct WM {
    static:
    private __gshared bool        isInit;
    private __gshared Lock        lock;
    private __gshared Framebuffer backBuffer;
    private __gshared Framebuffer frontBuffer;
    private __gshared Framebuffer realBuffer;
    private __gshared Cursor      cursor;
    private __gshared List!Window windows;
    private __gshared bool        hasBold;
    private __gshared PSFont      boldFont;
    private __gshared bool        hasCursive;
    private __gshared PSFont      cursiveFont;
    private __gshared bool        hasSans;
    private __gshared PSFont      sansFont;

    /// Create a WM for a physical framebuffer.
    void initialize(const ref KernelFramebuffer fb) {
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
        windows    = List!Window(5);
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
    long createWindow(string name) {
        lock.acquire();
        const ret = windows.push(Window(name, 300, 300));
        lock.release();
        return ret;
    }

    /// Fetch window for modifying.
    /// Params:
    ///     window = Window handle.
    /// Returns: Window pointer or null if not found.
    Window* fetchWindow(long window) {
        assert(window != -1);
        if (window >= windows.length || !windows.isPresent(window)) {
            return null;
        }
        return &windows[window];
    }

    /// Remove a window.
    /// Params:
    ///     window = Window to remove, never -1.
    void removeWindow(long window) {
        assert(window != -1 && window < windows.length);
        lock.acquire();
        windows.remove(window);
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
            if (windows.isPresent(i)) {
                windows[i].draw(bold, curs, sans, backBuffer);
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
                        if (windows.isPresent(i)) {
                            windows.remove(i);
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
                if (!windows.isPresent(i)) {
                    continue;
                }
                if (windows[i].isInWindow(cursorX, cursorY)) {
                    windows.swapIndexes(i, 0);
                    windows[0].setFocused(true);
                    auto w = &windows[0]; 
                    if (w.isTitleBar(cursorX, cursorY)) {
                        if (cursorX == 0 || cursorY == 0 ||
                            cursorX >= realBuffer.width - 1 || cursorY >= realBuffer.height - 1) {
                            return;
                        }
                        w.move(xVariation, yVariation);
                    } else if (w.isInLeftBorders(cursorX, cursorY)) {
                        w.resize(xVariation, yVariation, false);
                    } else if (w.isInRightBorders(cursorX, cursorY)) {
                        w.resize(xVariation, yVariation);
                    }
                    break;
                } else {
                    windows[i].setFocused(false);
                }
            }
        }
    }
}
