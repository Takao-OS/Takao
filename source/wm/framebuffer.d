/// Creating, managing, and deleting framebuffers.
module wm.framebuffer;

import stivale2:  Stivale2Framebuffer;
import lib.alloc: newObj, delObj, newArray, delArray;

alias Colour = int; /// Integer.

/// Data to represent a 32 bit framebuffer.
struct Framebuffer {
    bool    isPhysical; /// Whether the buffer is physical memory or allocated. 
    Colour* address;    /// Address of the framebuffer.
    size_t  width;      /// Width of the framebuffer in pixels.
    size_t  height;     /// Height of the framebuffer in pixels.
    size_t  pitch;      /// Pitch of the framebuffer in bytes.
}

/// Create a framebuffer.
/// Params:
///     fb = Stivale2 framebuffer tag, never null.
/// Returns: The created framebuffer, or `null` in failure.
Framebuffer* createFramebuffer(Stivale2Framebuffer* fb) {
    assert(fb != null);
    if (fb.bpp != 32) {
        return null;
    }

    auto ret = newObj!Framebuffer;
    if (ret == null) {
        return null;
    }

    ret.isPhysical = true;
    ret.address    = cast(Colour*)fb.address;
    ret.width      = fb.width;
    ret.height     = fb.height;
    ret.pitch      = fb.pitch;
    return ret;
}

/// Create a framebuffer.
/// Params:
///     width  = Width of the framebuffer in memory.
///     height = Height of the framebuffer in memory.
///     pitch  = Pitch of the framebuffer in memory in bytes.
/// Returns: The created framebuffer, or `null` in failure.
Framebuffer* createFramebuffer(size_t width, size_t height, size_t pitch) {
    auto ret = newObj!Framebuffer;
    if (ret == null) {
        return null;
    }
    auto arr = newArray!Colour(pitch * height); // @suppress(dscanner.suspicious.unmodified)
    if (arr == null) {
        delObj(ret);
        return null;
    }

    ret.isPhysical = false;
    ret.address    = arr;
    ret.width      = width;
    ret.height     = height;
    ret.pitch      = pitch;
    return ret;
}

/// Delete a framebuffer, after this, the pointer is unusable.
/// Params:
///     fb = Framebuffer to delete, never null.
void deleteFramebuffer(Framebuffer* fb) {
    assert(fb != null);
    if (!fb.isPhysical) {
        delArray(fb.address);
    }
    delObj(fb);
}

/// Put a pixel on the given coordinates.
/// Params:
///     fb = Framebuffer to write to, never null.
///     x  = X to write to.
///     y  = Y to write to.
///     c  = Colour to write.
void putFramebufferPixel(Framebuffer* fb, size_t x, size_t y, Colour c) {
    assert(fb != null);
    if (x >= fb.width || y >= fb.height) {
        return;
    }
    auto position = x + (fb.pitch / Colour.sizeof) * y;
    fb.address[position] = c;
}

/// Clear the passed framebuffer.
/// Params:
///     fb = Framebuffer to write to, never null.
///     c  = Colour to use for the clearing.
void clearFramebuffer(Framebuffer* fb, Colour c) {
    /// FIXME: Writting to the pitch could cause weirdness in some cases.
    assert(fb != null);
    const fbSize = (fb.pitch * fb.height) / Colour.sizeof;
    foreach (i; 0..fbSize) {
        fb.address[i] = c;
    }
}

/// Draw a character in the framebuffer.
/// Params:
///     fb  = Framebuffer to write to, never null.
///     fbX = X to write to.
///     fbY = Y to write to.
///     c   = Char to write.
///     fg  = Foreground color.
///     bg  = Background color.
void drawCharacter(Framebuffer* fb, size_t fbX, size_t fbY, char c, Colour fg, Colour bg) {
    import lib.bit: btInt;
    import wm.font: getFontCharacter, fontHeight, fontWidth;
    assert(fb != null);

    const character = getFontCharacter(c);
    foreach (int y; 0..fontHeight) {
        int currLine = fontWidth;
        foreach (int x; 0..fontWidth) {
            auto output = btInt(character[y], --currLine) ? fg : bg;
            putFramebufferPixel(fb, x + fbX, y + fbY, output);
        }
    }
}

/// Draw a string straight to the passed framebuffer using coordinates.
/// It doesnt handle newlines or any special characters.
/// Params:
///     fb  = Framebuffer to write to, never null.
///     fbX = X to write to.
///     fbY = Y to write to.
///     s   = String to write, never null.
///     fg  = Foreground color.
///     bg  = Background color.
void drawSimpleString(Framebuffer* fb, size_t fbX, size_t fbY, string s, Colour fg, Colour bg) {
    import display.font: fontWidth;
    assert(fb != null && s != null);
    foreach (i; 0..s.length) {
        drawCharacter(fb, fbX + (i * fontWidth), fbY, s[i], fg, bg);
    }
}
