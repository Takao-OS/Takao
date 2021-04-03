/// Utilities for printing cursors in framebuffers and
/// keeping their internal state.
module display.cursor;

import display.framebuffer: Framebuffer, Colour;

private immutable X = 0xffffff;
private immutable B = 0x000000;
private immutable o = -1;

private immutable cursorHeight = 21;
private immutable cursorWidth  = 15;
private immutable Colour[] cursor = [
    X, o, o, o, o, o, o, o, o, o, o, o, o, o, o,
    X, X, o, o, o, o, o, o, o, o, o, o, o, o, o,
    X, B, X, o, o, o, o, o, o, o, o, o, o, o, o,
    X, B, B, X, o, o, o, o, o, o, o, o, o, o, o,
    X, B, B, B, X, o, o, o, o, o, o, o, o, o, o,
    X, B, B, B, B, X, o, o, o, o, o, o, o, o, o,
    X, B, B, B, B, B, X, o, o, o, o, o, o, o, o,
    X, B, B, B, B, B, B, X, o, o, o, o, o, o, o,
    X, B, B, B, B, B, B, B, X, o, o, o, o, o, o,
    X, B, B, B, B, B, B, B, B, X, o, o, o, o, o,
    X, B, B, B, B, B, B, B, B, B, X, o, o, o, o,
    X, B, B, B, B, B, B, B, B, B, B, X, o, o, o,
    X, B, B, B, B, B, B, B, B, B, B, B, X, o, o,
    X, B, B, B, B, B, B, B, B, B, B, B, B, X, o,
    X, B, B, B, B, B, X, X, X, X, X, X, X, X, X,
    X, B, B, B, B, X, o, o, o, o, o, o, o, o, o,
    X, B, B, B, X, o, o, o, o, o, o, o, o, o, o,
    X, B, B, X, o, o, o, o, o, o, o, o, o, o, o,
    X, B, X, o, o, o, o, o, o, o, o, o, o, o, o,
    X, X, o, o, o, o, o, o, o, o, o, o, o, o, o,
    X, o, o, o, o, o, o, o, o, o, o, o, o, o, o,
];

/// Object to represent a cursor.
struct Cursor {
    long cursorX; /// Current X of the cursor.
    long cursorY; /// Current Y of the cursor.

    /// Update the position of the cursor, taking into account framebuffer
    /// limits and positions.
    void update(int xVariation, int yVariation, size_t height, size_t width) {
        if (cursorX + xVariation < 0) {
            cursorX = 0;
        } else if (cursorX + xVariation >= width) {
            cursorX = width - 1;
        } else {
            cursorX += xVariation;
        }

        if (cursorY + yVariation < 0) {
            cursorY = 0;
        } else if (cursorY + yVariation >= height) {
            cursorY = height - 1;
        } else {
            cursorY += yVariation;
        }
    }

    /// Draw the cursor on the tracked position.
    void draw(ref Framebuffer fb) {
        foreach (x; 0..cursorWidth) {
            foreach (y; 0..cursorHeight) {
                const px = cursor[y * cursorWidth + x];
                if (px != o) {
                    fb.putPixel(cursorX + x, cursorY + y, px);
                }
            }
        }
    }
}
