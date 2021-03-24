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

private __gshared long cursorX;
private __gshared long cursorY;

/// Draw the cursor again given an amount of position variation.
void updateCursor(int xVariation, int yVariation, size_t height, size_t width) {
    if (cursorX + xVariation < 0) {
        cursorX = 0;
    } else if (cursorX + xVariation + cursorWidth >= width) {
        cursorX = width - 1 - cursorWidth;
    } else {
        cursorX += xVariation;
    }

    if (cursorY + yVariation < 0) {
        cursorY = 0;
    } else if (cursorY + yVariation + cursorHeight >= height) {
        cursorY = height - 1 - cursorHeight;
    } else {
        cursorY += yVariation;
    }
}

/// Get the absolute coordinates of the cursor.
void getCursorPosition(ref size_t x, ref size_t y) {
    x = cursorX;
    y = cursorY;
}

/// Draw the cursor on the tracked position.
void drawCursor(Framebuffer *fb) {
    foreach (x; 0..cursorWidth) {
        foreach (y; 0..cursorHeight) {
            const Colour px = cursor[y * cursorWidth + x];
            if (px != o) {
                fb.putPixel(cursorX + x, cursorY + y, px);
            }
        }
    }
}
