/// Framebuffer manipulation goodies.
module display.framebuffer;

import kernelprotocol: KernelFramebuffer;
import memory.alloc:   allocate, free;

alias Colour = uint; /// Colours the framebuffer accepts.

/// Struct for managing framebuffers and common functions.
struct Framebuffer {
    Colour* address;  /// Address of the framebuffer content.
    bool    isMemory; /// Whether the framebuffer is in memory.
    size_t  width;    /// Width of the framebuffer in pixels.
    size_t  height;   /// Height of the framebuffer in pixels.
    size_t  pitch;    /// Pitch of the framebuffer in pixels.
    size_t  size;     /// Size of the framebuffer in pixels, with pitch.

    /// Create a framebuffer from a stivale framebuffer.
    this(const ref KernelFramebuffer fb) {
        address  = cast(Colour*)fb.address;
        isMemory = false;
        width    = fb.width;
        height   = fb.height;
        pitch    = fb.pitch / Colour.sizeof;
        size     = fb.pitch * fb.height;
    }

    /// Create a framebuffer in memory.
    this(size_t fbWidth, size_t fbHeight, size_t fbPitch) {
        size     = fbPitch * fbHeight;
        address  = allocate!Colour(size / Colour.sizeof);
        isMemory = true;
        width    = fbWidth;
        height   = fbHeight;
        pitch    = fbPitch / Colour.sizeof;
    }

    ~this() {
        if (isMemory) {
            free(address);
        }
    }

    invariant {
        assert(pitch % Colour.sizeof == 0, "Pitch is not a multiple of 4");
    }

    /// Put pixel on coordinates.
    void putPixel(size_t x, size_t y, Colour c) {
        if (x >= width || y >= height) {
            return;
        }
        auto position = x + pitch * y;
        address[position] = c;
    }

    /// Paint the whole framebuffer in one colour.
    void clear(Colour c) {
        const size_t fbSize = size / Colour.sizeof;
        for (size_t i = 0; i < fbSize; i++) {
            address[i] = c;
        }
    }

    /// Draw character from font straight to the framebuffer using coordinates.
    void drawCharacter(size_t fbX, size_t fbY, char c, Colour fg, Colour bg) {
        import lib.bit:             bittest;
        import display.defaultfont: getFontCharacter, fontHeight, fontWidth;

        const auto character = getFontCharacter(c);
        foreach (int y; 0..fontHeight) {
            int currLine = fontWidth;
            foreach (int x; 0..fontWidth) {
                auto output = bittest(character[y], --currLine) ? fg : bg;
                putPixel(x + fbX, y + fbY, output);
            }
        }
    }

    /// Draw a string straight to the passed framebuffer using coordinates.
    void drawString(size_t fbX, size_t fbY, string s, Colour fg, Colour bg) {
        import display.defaultfont: fontWidth;
        for (size_t i = 0; i < s.length; i++) {
            drawCharacter(fbX + (i * fontWidth), fbY, s[i], fg, bg);
        }
    }
}
