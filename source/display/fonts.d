/// Utilities for displaying and using fonts.
module display.fonts;

import storage.file: FileMode, open, close, read, length;
import memory.alloc: allocate, free;
debug import lib.debugtools: warn;

private immutable psfMagic = 0x864AB572;

private struct PSFHeader {
    align(1):
    uint magic;
    uint vers;
    uint headersize;
    uint flags;
    uint numglyph;
    uint bytesperglyph;
    uint height;
    uint width;
}

/// PC Screen Font renderer.
struct PSFont {
    private bool       isInit;
    private ubyte*     font;
    private PSFHeader* header;
    private ubyte*     fontInner;
    size_t fontWidth;  /// Width of the font in pixels.
    size_t fontHeight; /// Height of the font in pixels.

    /// Load a font into an object.
    this(string pathToLoad, ref bool success) {
        assert(pathToLoad != null);
        const fd = open(pathToLoad, FileMode.Read);
        if (fd == -1) {
            debug warn("Could not open font at ", pathToLoad);
            success = false;
            return;
        }
        const len = length(fd);
        if (len == -1) {
            debug warn("Could not fetch length of ", fd);
            success = false;
            close(fd);
            return;
        }
        font = allocate!ubyte(len);
        if (read(fd, font, len) == -1) {
            debug warn("Could not read font at ", fd);
            success = false;
            close(fd);
            free(font);
            return;
        }
        close(fd);
        header    = cast(PSFHeader*)font;
        fontInner = font + PSFHeader.sizeof;
        /// TODO: Support unicode tables (flags != 0).
        if (header.magic != psfMagic || header.flags != 0) {
            debug warn("File ", pathToLoad, " is not a PS Font");
            success = false;
            free(font);
            return;
        }
        fontHeight = header.height;
        fontWidth  = header.width;
        isInit     = true;
    }

    ~this() {
        if (isInit) {
            free(font);
        }
    }

    ubyte[] getFontCharacter(char c) {
        const index = header.bytesperglyph * c;
        const end   = index + header.bytesperglyph;
        return font[index..end];
    }
}
