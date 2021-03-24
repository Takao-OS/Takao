/// Driver for the PS2 keyboard.
/// No detection is needed since if it doesn't exist the IRQ will just not
/// fire, since it's hardcoded by the platform.
module arch.x86_64_stivale2.ps2keyboard;

// Keep track of board status.
private shared bool isCapslockActive;
private shared bool isShiftActive;
private shared bool isCtrlActive;
private shared bool isAltActive;
private shared bool hasExtraScancode;

// Special keys and values.
private immutable maxCode           = 0x57;
private immutable capslockPress     = 0x3a;
private immutable leftAltPress      = 0x38;
private immutable leftAltRelease    = 0xb8;
private immutable rightShiftPress   = 0x36;
private immutable leftShiftPress    = 0x2a;
private immutable rightShiftRelease = 0xb6;
private immutable leftShiftRelease  = 0xaa;
private immutable ctrlPress         = 0x1d;
private immutable ctrlRelease       = 0x9d;

// Standard US keyboard mappings.
private immutable char[] mappingCapslock = [
    '\0', '\033', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b',
    '\t', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '[', ']', '\n',
    '\0', 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ';', '\'', '`', '\0',
    '\\', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.', '/', '\0', '\0', '\0', ' '
];

private immutable char[] mappingShift = [
    '\0', '\033', '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '\b',
    '\t', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n',
    '\0', 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', '\0', '|',
    'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', '\0', '\0', '\0', ' '
];

private immutable char[] mappingShiftCapslock = [
    '\0', '\033', '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '\b',
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '{', '}', '\n',
    '\0', 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ':', '"', '~', '\0', '|',
    'z', 'x', 'c', 'v', 'b', 'n', 'm', '<', '>', '?', '\0', '\0', '\0', ' '
];

private immutable char[] mappingNoModifiers = [
    '\0', '\033', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b',
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',
    '\0', 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', '\0', '\\',
    'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', '\0', '\0', '\0', ' '
];

/// Start the PS2 keyboard.
void initPS2Keyboard() {
    import arch.x86_64_stivale2.apic: ioAPICSetUpLegacyIRQ;
    ioAPICSetUpLegacyIRQ(0, 1, true);
}

/// Handler to be called when a keypress is ready.
extern (C) void keyboardHandler() {
    import display.wm: wmKeyboardEntry;
    import arch.x86_64_stivale2.cpu: inb;

    const ubyte input = inb(0x60);
    if (input == 0xe0) {
        hasExtraScancode = true;
        return;
    }

    // Get ctrl out of the way.
    if (hasExtraScancode) {
        switch (input) {
            case ctrlPress:   isCtrlActive = true;  return;
            case ctrlRelease: isCtrlActive = false; return;
            default:          break;
        }
    }

    // Special keys.
    switch (input) {
        case leftAltPress:      isAltActive      = true;              return;
        case leftAltRelease:    isAltActive      = false;             return;
        case leftShiftPress:    isShiftActive    = true;              return;
        case rightShiftPress:   isShiftActive    = true;              return;
        case leftShiftRelease:  isShiftActive    = false;             return;
        case rightShiftRelease: isShiftActive    = false;             return;
        case ctrlPress:         isCtrlActive     = true;              return;
        case ctrlRelease:       isCtrlActive     = false;             return;
        case capslockPress:     isCapslockActive = !isCapslockActive; return;
        default:                break;
    }

    // Assign the pressed char based on special keys.
    char c = '\0';
    if (input < maxCode) {
        if (isCtrlActive) {
            // TODO: Proper caret notation would be nice
            c = cast(char)(mappingCapslock[input] - ('?' + 1));
        } else if (!isCapslockActive && !isShiftActive) {
            c = mappingNoModifiers[input];
        } else if (!isCapslockActive && isShiftActive) {
            c = mappingShift[input];
        } else if (isCapslockActive && isShiftActive) {
            c = mappingShiftCapslock[input];
        } else {
            c = mappingCapslock[input];
        }

        // Go to the WM.
        wmKeyboardEntry(isAltActive, c);
    }
}
