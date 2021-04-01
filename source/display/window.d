/// The window struct and window utilities.
module display.window;

import lib.list:            List;
import display.framebuffer: Framebuffer, Colour;
import display.fonts:       PSFont;

private immutable titleFontColour        = 0xffffff;
private immutable focusedTitleBackground = 0xff8888;
private immutable titleBackground        = 0x888888;
private immutable windowBackground       = 0xdddddd;
private immutable fontColour             = 0x000000;

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
    private bool            isInitialized;
    private bool            isFocused;
    private string          titleString;
    private size_t          windowX;
    private size_t          windowY;
    private size_t          canvasWidth;
    private size_t          canvasHeight;
    private List!TextWidget textWidgets;

    /// Creates the object.
    this(string title, size_t windowWidth, size_t windowHeight) {
        isInitialized = true;
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

        // Readjust ourselves if needed.
        if (windowX >= fb.width) {
            windowX = 0;
        }
        if (windowX + canvasWidth >= fb.width) {
            windowX = fb.width - canvasWidth;
        }
        if (windowY >= fb.height) {
            windowY = 0;
        }
        if (windowY + canvasHeight + fontHeight >= fb.height) {
            windowY = fb.height - canvasHeight - fontHeight;
        }

        // Title and border work.
        auto colour = isFocused ? focusedTitleBackground : titleBackground;
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
            const len = textWidgets[i].message.length;
            size_t x;
            size_t y;
            if (textWidgets[i].isCenterWidth) {
                x = (canvasWidth / 2) - (len / 2 * fontWidth);
            } else {
                x = textWidgets[i].widthPercent * canvasWidth  / 100;
            }
            if (textWidgets[i].isCenterHeight) {
                y = canvasHeight / 2;
            } else {
                y = textWidgets[i].heightPercent * canvasHeight / 100;
            }
            x += windowX;
            y += windowY + fontHeight;
            for (size_t j = 0; j < textWidgets[i].message.length; j++) {
                const finalX = x + (j * fontWidth);
                if (finalX < windowX || (finalX + fontWidth) > windowX + canvasWidth) {
                    continue;
                } 
                fb.drawCharacter(finalX, y, textWidgets[i].message[j], fontColour, windowBackground);
            }
        }
    }

    /// Move window.
    void move(int differenceX, int differenceY) {
        windowX += differenceX;
        windowY += differenceY;
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
    bool isTitleBar(size_t x, size_t y) {
        import display.defaultfont: fontWidth, fontHeight;
        return x >= windowX && x <= windowX + canvasWidth && y >= windowY && y <= windowY + fontHeight;
    }

    /// Check if an absolute pair of coordinates is in the window, includes titlebar.
    bool isInWindow(size_t x, size_t y) {
        import display.defaultfont: fontWidth, fontHeight;
        return x >= windowX && x <= windowX + canvasWidth && y >= windowY && y <= windowY + fontHeight + canvasHeight;
    }

    /// Check if an absolute pair of coordinates is in the left borders.
    bool isInLeftBorders(size_t x, size_t y) {
        import display.defaultfont: fontWidth, fontHeight;
        return x == windowX && y >= windowY && y <= canvasHeight + windowY + fontHeight;
    }

    /// Check if an absolute pair of coordinates is in the left borders.
    bool isInRightBorders(size_t x, size_t y) {
        import display.defaultfont: fontWidth, fontHeight;
        return x == windowX + canvasWidth && y >= windowY && y <= canvasHeight + windowY + fontHeight;
    }
}
