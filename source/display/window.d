/// The window struct and window utilities.
module display.window;

import display.framebuffer: Framebuffer, Colour;
import memory.alloc:        allocate, free, resizeAllocationAbs;

private immutable titleBarFontColour    = 0xffffff;
private immutable focusedTitleBarColour = 0xff8888;
private immutable defaultTitleBarColour = 0x888888;

/// Struct that represents a window.
struct Window {
    private bool    isFocused;
    private string  titleString;
    private size_t  windowX;
    private size_t  windowY;
    private size_t  canvasWidth;
    private size_t  canvasHeight;
    private bool    isCanvasOurs;
    private bool    needsResize;
    private Colour* canvas;

    /// Creates the object.
    this(string title, size_t windowWidth, size_t windowHeight) {
        isFocused    = false;
        titleString  = title;
        windowX      = 30;
        windowY      = 30;
        canvasWidth  = windowWidth;
        canvasHeight = windowHeight;
        isCanvasOurs = true;
        needsResize  = false;
        canvas       = allocate!Colour(canvasWidth * canvasHeight);
    }

    /// Delete the object.
    ~this() {
        if (isCanvasOurs) {
            free(canvas);
        }
    }

    /// Get the canvas.
    @property Colour* userCanvas() { return canvas; }
    /// Get the canvas width.
    @property size_t userCanvasWidth() { return canvasWidth; }
    /// Get the canvas height.
    @property size_t userCanvasHeight() { return canvasHeight; }

    /// Draw window.
    void draw(Framebuffer *fb) {
        import display.font: fontWidth, fontHeight;

        if (needsResize) {
            resizeAllocationAbs(&canvas, canvasWidth * canvasHeight);
            needsResize = false;
        }

        // Readjust ourselves if needed.
        if (windowX >= fb.getWidth()) {
            windowX = 0;
        }
        if (windowX + canvasWidth >= fb.getWidth()) {
            windowX = fb.getWidth() - canvasWidth;
        }
        if (windowY >= fb.getHeight()) {
            windowY = 0;
        }
        if (windowY + canvasHeight + fontHeight >= fb.getHeight()) {
            windowY = fb.getHeight() - canvasHeight - fontHeight;
        }

        // Title work.
        auto colour = isFocused ? focusedTitleBarColour : defaultTitleBarColour;
        foreach (i; 0..canvasWidth) {
            foreach (j; 0..fontHeight) {
                fb.putPixel(windowX + i, windowY + j, colour);
            }
        }
        fb.drawString(windowX, windowY, titleString, titleBarFontColour, colour);

        // Canvas.
        foreach (i; 0..canvasWidth) {
            foreach (j; 0..canvasHeight) {
                fb.putPixel(windowX + i, windowY + fontHeight + j, canvas[i + canvasWidth * j]);
            }
        }
    }

    /// Move window.
    void move(int differenceX, int differenceY) {
        windowX += differenceX;
        windowY += differenceY;
    }

    /// Set the canvas to a custom one.
    void setCanvas(Colour *c) {
        isCanvasOurs = false;
        canvas       = c;
    }

    /// Resize window, by default from the right.
    void resize(int xVariation, int yVariation, bool fromTheRight = true) {
        if (fromTheRight) {
            if (canvasWidth + xVariation < size_t.max) {
                canvasWidth += xVariation;
            }
            if (canvasHeight + yVariation < size_t.max) {
                canvasHeight += yVariation;
            }
        } else {
            if (canvasWidth + xVariation < size_t.max) {
                windowX     += xVariation;
                canvasWidth -= xVariation;
            }
            if (canvasHeight + yVariation < size_t.max) {
                windowY      += yVariation;
                canvasHeight -= yVariation;
            }
        }

        if (isCanvasOurs) {
            needsResize = true;
        }
    }

    /// Set the window as focused.
    void setFocused(bool focus) {
        isFocused = focus;
    }

    /// Check if an absolute pair of coordinates is in the titlebar.
    bool isTitleBar(size_t x, size_t y) {
        import display.font: fontWidth, fontHeight;
        return x >= windowX && x <= windowX + canvasWidth && y >= windowY && y <= windowY + fontHeight;
    }

    /// Check if an absolute pair of coordinates is in the window, includes titlebar.
    bool isInWindow(size_t x, size_t y) {
        import display.font: fontWidth, fontHeight;
        return x >= windowX && x <= windowX + canvasWidth && y >= windowY && y <= windowY + fontHeight + canvasHeight;
    }

    /// Check if an absolute pair of coordinates is in the left borders.
    bool isInLeftBorders(size_t x, size_t y) {
        import display.font: fontWidth, fontHeight;
        return x == windowX && y >= windowY && y <= canvasHeight + windowY + fontHeight;
    }

    /// Check if an absolute pair of coordinates is in the left borders.
    bool isInRightBorders(size_t x, size_t y) {
        import display.font: fontWidth, fontHeight;
        return x == windowX + canvasWidth && y >= windowY && y <= canvasHeight + windowY + fontHeight;
    }

    /// Put pixel in canvas, its assumed to be in the window.
    void putPixel(size_t x, size_t y, Colour colour) {
        import display.font: fontHeight;
        size_t positionX = x - windowX;
        size_t positionY = y - windowY - fontHeight;
        canvas[positionX + canvasWidth * positionY] = colour;
    }
}
