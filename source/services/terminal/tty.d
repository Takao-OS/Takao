module services.terminal.tty;

import memory.virtual;
import lib.alloc;
import lib.stivale;
import lib.bit;
import services.terminal.font;
import services.terminal.framebuffer;

private immutable PALETTE = [
    0x3F3F3F, // Black.
    0x705050, // Red.
    0x60B48A, // Green.
    0xDFAF8F, // Yellow.
    0x9AB8D7, // Blue.
    0xDC8CC3, // MAgenta.
    0x8CD0D3, // Cyan.
    0xDCDCDC  // White.
];

private immutable BACKGROUND = 0x2C2C2C;
private immutable FOREGROUND = 0xDCDCDC;

struct TTY {
    private Framebuffer* framebuffer;
    private GridElem*    grid;
    private Colour       background;
    private Colour       foreground;
    private uint         rows;
    private uint         columns;
    private uint         currentRow;
    private uint         currentColumn;

    private struct GridElem {
        char   character;
        Colour colour;
    }

    this(StivaleFramebuffer fb) {
        this.framebuffer   = newObj!Framebuffer(fb);
        this.background    = BACKGROUND;
        this.foreground    = FOREGROUND;
        this.rows          = fb.height / FONT_HEIGHT;
        this.columns       = fb.width  / FONT_WIDTH;
        this.currentRow    = 0;
        this.currentColumn = 0;
        this.grid          = newArray!GridElem(this.rows * this.columns);
    }

    void clear() {
        this.currentRow    = 0;
        this.currentColumn = 0;
        this.framebuffer.clear(this.background);
    }

    void print(string str) {
        for (int i = 0; i < str.length; i++) {
            if (str[i] == '\033' && str.length > i + 3) {
                i += 3;
                if (str[i] == 'm') {
                    this.foreground = FOREGROUND;
                } else {
                    this.foreground = PALETTE[str[i] - '0'];
                    i += 1;
                }
            } else {
                this.print(str[i]);
            }
        }
    }

    void print(char c) {
        switch (c) {
            case '\n':
                this.currentRow++;
                this.currentColumn = 0;
                break;
            default:
                if (this.currentColumn == this.columns) {
                    print('\n');
                }

                if (this.currentRow == this.rows) {
                    this.scroll();
                }

                this.print(this.currentRow, this.currentColumn, c, this.foreground);
                this.currentColumn++;
        }
    }

    void print(int row, int column, char c, Colour colour) {
        size_t index = row * this.rows + column;
        this.grid[index] = GridElem(c, this.foreground);

        auto character = getFontCharacter(c);
        auto fbIndexX  = column * FONT_WIDTH;
        auto fbIndexY  = row * FONT_HEIGHT;

        foreach (int y; 0..FONT_HEIGHT) {
            int asd = FONT_WIDTH;
            foreach (int x; 0..FONT_WIDTH) {
                auto output = btInt(character[y], --asd) ? colour : this.background;
                this.framebuffer.putPixel(x + fbIndexX, y + fbIndexY, output);
            }
        }
    }

    private void scroll() {
        foreach (int row; 1..(this.rows - 1)) {
            foreach (int col; 0..this.columns) {
                size_t index  = (row - 1) * this.rows + col;
                auto   colour = this.grid[index].colour;
                this.print(row, col, this.grid[index].character, colour);
            }
        }

        foreach (int col; 0..this.columns) {
            this.print(this.rows - 1, col, ' ', this.foreground);
        }
    }

    ~this() {
        delObj(this.framebuffer);
    }
}
