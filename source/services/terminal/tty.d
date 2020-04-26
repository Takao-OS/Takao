module services.terminal.tty;

import memory.virtual;
import lib.alloc;
import stivale;
import lib.bit;
import services.terminal.font;
import services.terminal.framebuffer;

private immutable palette = [
    0x3f3f3f, // Black.
    0x705050, // Red.
    0x60b48a, // Green.
    0xdfaf8f, // Yellow.
    0x9ab8d7, // Blue.
    0xdc8cc3, // MAgenta.
    0x8cd0d3, // Cyan.
    0xdcdcdc  // White.
];

private immutable background = 0x2c2c2c;
private immutable foreground = 0xdcdcdc;

struct TTY {
    private immutable uint rows;
    private immutable uint columns;
    private Framebuffer* framebuffer;
    private GridElem*    grid;
    private Colour       currentForeground;
    private uint         currentRow;
    private uint         currentColumn;

    private struct GridElem {
        char   character;
        Colour foreground;
    }

    this(StivaleFramebuffer fb) {
        rows              = fb.height / fontHeight;
        columns           = fb.width  / fontWidth;
        framebuffer       = newObj!Framebuffer(fb);
        grid              = newArray!GridElem(rows * columns);
        currentForeground = foreground;
        currentRow        = 0;
        currentColumn     = 0;
    }

    void print(string str) {
        for (int i = 0; i < str.length; i++) {
            if (str[i] == '\033' && str.length > i + 3) {
                i += 3;
                if (str[i] == 'm') {
                    currentForeground = foreground;
                } else {
                    currentForeground = palette[str[i] - '0'];
                    i += 1;
                }
            } else {
                print(str[i]);
            }
        }
    }

    void print(char c) {
        switch (c) {
            case '\n':
                if (++currentRow >= rows) {
                    scroll();
                    currentRow = rows - 1;
                }
                currentColumn = 0;
                break;
            default:
                if (currentColumn >= columns) {
                    currentRow++;
                    currentColumn = 0;
                }
                if (currentRow >= rows) {
                    scroll();
                }
                print(currentRow, currentColumn, c, currentForeground);
                currentColumn++;
        }
    }

    void clear() {
        currentRow    = 0;
        currentColumn = 0;
        framebuffer.clear(background);
        foreach (i; 0..getArraySize(grid)) {
            grid[i] = GridElem(' ', foreground);
        }
    }

    private void print(int row, int column, char c, Colour colour) {
        size_t index = column + row * columns;
        grid[index] = GridElem(c, colour);

        auto character = getFontCharacter(c);
        auto fbIndexX  = column * fontWidth;
        auto fbIndexY  = row * fontHeight;

        foreach (int y; 0..fontHeight) {
            int asd = fontWidth;
            foreach (int x; 0..fontWidth) {
                auto output = btInt(character[y], --asd) ? colour : background;
                framebuffer.putPixel(x + fbIndexX, y + fbIndexY, output);
            }
        }
    }

    private void scroll() {
        foreach (row; 1..rows) {
            foreach (col; 0..columns) {
                auto index = col + row * columns;
                auto colour = grid[index].foreground;
                print(row - 1, col, grid[index].character, colour);
            }
        }

        foreach (col; 0..columns) {
            print(rows - 1, col, ' ', foreground);
        }
    }

    ~this() {
        delObj(framebuffer);
        delArray(grid);
    }
}
