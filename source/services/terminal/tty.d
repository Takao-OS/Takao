module services.terminal.tty;

import memory.virtual;
import lib.alloc;
import lib.stivale;
import services.terminal.font;
import services.terminal.framebuffer;

immutable PALETTE = [
    0x000000, // Black.
    0xFF0000, // Red.
    0x00FF00, // Green.
    0xFFFF55, // Yellow.
    0x5555FF, // Blue.
    0xFF55FF, // MAgenta.
    0x55FFFF, // Cyan.
    0xFFFFFF  // White.
];

struct TTY {
    private Framebuffer* framebuffer;
    private Colour       background;
    private Colour       foreground;
    private Colour       currentColour;
    private uint         rows;
    private uint         columns;
    private uint         currentRow;
    private uint         currentColumn;

    this(StivaleFramebuffer fb) {
        this.framebuffer   = newObj!Framebuffer(fb);
        this.background    = PALETTE[0];
        this.foreground    = PALETTE[7];
        this.rows          = fb.height / FONT_HEIGHT;
        this.columns       = fb.width  / FONT_WIDTH;
        this.currentRow    = 0;
        this.currentColumn = 0;
    }

    void clear() {
        this.currentRow    = 0;
        this.currentColumn = 0;
        this.framebuffer.clear(this.background);
    }

    void print(string str) {
        return;
    }

    void print(char c) {
        return;
    }

    ~this() {
        delObj(this.framebuffer);
    }
}
