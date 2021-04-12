/// The window struct and window utilities.
module display.window;

import lib.list:            List;
import display.defaultfont: fontHeight, fontWidth, getFontCharacter;
import display.framebuffer: Framebuffer, Colour;
import display.fonts:       PSFont;

private immutable titleFontColour    = 0xffffff;
private immutable focusedTitleBorder = 0xff8888;
private immutable titleBorder        = 0x888888;
private immutable windowBackground   = 0xdddddd;
private immutable fontColour         = 0x000000;

/// Text widget.
struct TextWidget {
    bool   isCenterHeight; /// Whether the widget is centered in height.
    bool   isCenterWidth;  /// Whether the widget is centered in width.
    ubyte  heightPercent;  /// Percentage of the string in height.
    ubyte  widthPercent;   /// Percentage of the position in width.
    string message;        /// Message to print.
}

/// Struct that represents a window.
struct Window {
    private bool            isFocused;
    private string          titleString;
    private long            windowX;
    private long            windowY;
    private size_t          canvasWidth;
    private size_t          canvasHeight;
    private List!TextWidget textWidgets;

    /// Creates the object.
    this(string title, size_t windowWidth, size_t windowHeight) {
        titleString   = title;
        windowX       = 30;
        windowY       = 30;
        canvasWidth   = windowWidth;
        canvasHeight  = windowHeight;
        textWidgets   = List!TextWidget(2);
    }

    /// Add widget.
    void addWidget(TextWidget widget) {
        textWidgets.push(widget);
    }

    /// Draw window.
    /// Params:
    ///     bold    = Bold font to use, null if none.
    ///     cursive = Cursive font to use, null if none.
    ///     sans    = Sans font to use, null if none.
    ///     fb      = Framebuffer to print to.
    void draw(PSFont* bold, PSFont* cursive, PSFont* sans, ref Framebuffer fb) {
        import display.defaultfont: fontWidth, fontHeight;

        // Title and border work.
        import lib.debugtools: log;

        auto colour = isFocused ? focusedTitleBorder : titleBorder;
        foreach (i; 0..canvasWidth) {
            foreach (j; 0..fontHeight) {
                fb.putPixel(windowX + i, windowY + j, colour);
            }
        }
        fb.drawString(windowX, windowY, titleString, titleFontColour, colour);
        foreach (i; 0..(canvasHeight + fontHeight)) {
            fb.putPixel(windowX - 1,           windowY + i, colour);
            fb.putPixel(windowX + canvasWidth, windowY + i, colour);
        }
        foreach (i; 0..canvasWidth) {
            fb.putPixel(windowX + i, windowY + canvasHeight + fontHeight, colour);
        }

        // Background of the window.
        foreach (i; 0..canvasWidth) {
            foreach (j; 0..canvasHeight) {
                fb.putPixel(windowX + i, windowY + fontHeight + j, windowBackground);
            }
        }

        // Draw text widgets.
        foreach (i; 0..textWidgets.length) {
            const msg = textWidgets[i].message;
            const len = msg.length;
            long x;
            long y;
            if (textWidgets[i].isCenterWidth) {
                x = (canvasWidth / 2) - (len / 2 * fontWidth);
            } else {
                x = textWidgets[i].widthPercent * canvasWidth / 100;
            }
            if (textWidgets[i].isCenterHeight) {
                y = canvasHeight / 2;
            } else {
                y = textWidgets[i].heightPercent * canvasHeight / 100;
            }

            for (long j = 0; j < len; j++) {
                const finalX = x + (j * fontWidth);
                if (finalX < 0 || finalX + fontWidth > canvasWidth) {
                    continue;
                }
                fb.drawCharacter(windowX + finalX, windowY + y, msg[j], fontColour, windowBackground);
            }
        }
    }

    /// Move window.
    void move(int differenceX, int differenceY) {
        windowX += differenceX;
        windowY += differenceY;
        if (windowY < 0) {
            windowY = 0;
        }
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
    }

    /// Set the window as focused.
    void setFocused(bool focus) {
        isFocused = focus;
    }

    /// Check if an absolute pair of coordinates is in the titlebar.
    bool isTitleBar(long x, long y) {
        import display.defaultfont: fontWidth, fontHeight;
        return x >= windowX && x <= windowX + canvasWidth && y >= windowY && y <= windowY + fontHeight;
    }

    /// Check if an absolute pair of coordinates is in the window, includes titlebar.
    bool isInWindow(long x, long y) {
        import display.defaultfont: fontWidth, fontHeight;
        return x >= windowX && x <= windowX + canvasWidth && y >= windowY && y <= windowY + fontHeight + canvasHeight;
    }

    /// Check if an absolute pair of coordinates is in the left borders.
    bool isInLeftBorders(long x, long y) {
        import display.defaultfont: fontWidth, fontHeight;
        return x == windowX && y >= windowY && y <= canvasHeight + windowY + fontHeight;
    }

    /// Check if an absolute pair of coordinates is in the left borders.
    bool isInRightBorders(long x, long y) {
        import display.defaultfont: fontWidth, fontHeight;
        return x == windowX + canvasWidth && y >= windowY && y <= canvasHeight + windowY + fontHeight;
    }
}
