/// Driver for the PS2 mouse.
/// No detection is needed since if it doesn't exist the IRQ will just not
/// fire, since it's hardcoded by the platform.
module arch.x86_64_stivale2.ps2mouse;

import arch.x86_64_stivale2.cpu: inb, outb;

private struct PS2MousePacket {
    ubyte flags;
    ubyte xMovement;
    ubyte yMovement;
}

/// Start the PS2 mouse.
void initPS2Mouse() {
    import arch.x86_64_stivale2.apic: ioAPICSetUpLegacyIRQ;

    // Init the mouse.
    mouseWaitWrite();
    outb(0x64, 0xa8);

    mouseWaitWrite();
    outb(0x64, 0x20);
    ubyte status = mouseRead();
    mouseRead();
    status |= (1 << 1);
    status &= ~(1 << 5);
    mouseWaitWrite();
    outb(0x64, 0x60);
    mouseWaitWrite();
    outb(0x60, status);
    mouseRead();

    mouseWrite(0xf6);
    mouseRead();

    mouseWrite(0xf4);
    mouseRead();

    // Unmask.
    ioAPICSetUpLegacyIRQ(0, 12, true);
}

private __gshared int            mouseCycle;
private __gshared PS2MousePacket currentPacket;

/// Handler to be called when a mouse movement is ready.
extern (C) void mouseHandler() {
    import display.wm:           WM;
    debug import lib.debugtools: warn;

    switch (mouseCycle) {
        case 0:
            currentPacket.flags = inb(0x60);
            if (currentPacket.flags & (1 << 6) || currentPacket.flags & (1 << 7)
                || !(currentPacket.flags & (1 << 3))) {
                mouseCycle = 0;
                return;
            }
            mouseCycle++;
            break;
        case 1:
            currentPacket.xMovement = inb(0x60);
            mouseCycle++;
            break;
        default:
            currentPacket.yMovement = inb(0x60);
            mouseCycle              = 0;

            bool isLeftClick;
            bool isRightClick;
            int  xVariation;
            int  yVariation;
            if (currentPacket.flags & (1 << 0)) {
                isLeftClick = true;
            }
            if (currentPacket.flags & (1 << 1)) {
                isRightClick = true;
            }
            if (currentPacket.flags & (1 << 4)) {
                xVariation = cast(byte)currentPacket.xMovement;
            } else {
                xVariation = currentPacket.xMovement;
            }
            if (currentPacket.flags & (1 << 5)) {
                yVariation = cast(byte)currentPacket.yMovement;
            } else {
                yVariation = currentPacket.yMovement;
            }
            WM.mouseEvent(xVariation, -yVariation, isLeftClick, isRightClick);
    }
}

private void mouseWaitRead() {
    int timeout = 100_000;

    while (timeout--) {
        if (inb(0x64) & (1 << 0)) {
            return;
        }
    }
}

private void mouseWaitWrite() {
    int timeout = 100_000;

    while (timeout--) {
        if (!(inb(0x64) & (1 << 1))) {
            return;
        }
    }
}

private void mouseWrite(ubyte value) {
    mouseWaitWrite();
    outb(0x64, 0xd4);
    mouseWaitWrite();
    outb(0x60, value);
}

private ubyte mouseRead() {
    mouseWaitRead();
    return inb(0x60);
}
