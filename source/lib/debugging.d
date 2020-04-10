module lib.debugging;

import core.stdc.stdarg;
import system.cpu;

public alias cstring = immutable(char)*;

private immutable CONVERSION_TABLE = "0123456789ABCDEF";
private immutable cstring CRED     = "\033[31m";
private immutable cstring CCYAN    = "\033[36m";
private immutable cstring CRESET   = "\033[0m";

private void print(char c) {
    outb(0xE9, c);
}

private void print(cstring s) {
    for (auto i = 0; s[i] != '\0'; i++) {
        print(s[i]);
    }
}

private void printInt(ulong x) {
    int i;
    char[21] buf;

    buf[20] = 0;

    if (!x) {
        print('0');
        return;
    }

    for (i = 19; x; i--) {
        buf[i] = CONVERSION_TABLE[x % 10];
        x /= 10;
    }

    i++;
    print(cast(immutable)&buf[i]);
}

private void printHex(ulong x) {
    int i;
    char[17] buf;

    buf[16] = 0;

    if (!x) {
        print("0x0");
        return;
    }

    for (i = 15; x; i--) {
        buf[i] = CONVERSION_TABLE[x % 16];
        x /= 16;
    }

    i++;
    print("0x");
    print(cast(immutable)&buf[i]);
}

private extern(C) void vprint(cstring format, va_list args) {
    for (auto i = 0; format[i]; i++) {
        if (format[i] != '%') {
            print(format[i]);
            continue;
        }

        if (format[++i]) {
            switch (format[i]) {
                case 's':
                    cstring str;
                    va_arg(args, str);
                    print(str);
                    break;
                case 'x':
                    ulong h;
                    va_arg(args, h);
                    printHex(h);
                    break;
                case 'u':
                    ulong u;
                    va_arg(args, u);
                    printInt(u);
                    break;
                default:
                    print('%');
                    print(format[i]);
            }
        } else print('%');
    }
}


private extern(C) void printf(cstring message, ...) {
    va_list args;
    va_start(args, message);
    vprint(message, args);
    va_end(args);
}

extern(C) void writeln(cstring s, ...) {
    va_list args;
    va_start(args, s);

    printf("[%s*%s] ", CCYAN, CRESET);
    vprint(s, args);
    print('\n');

    va_end(args);
}

extern(C) void panic(cstring message, ...) {
    va_list args;
    va_start(args, message);

    printf("[%sX%s] ", CRED, CRESET);
    vprint(message, args);
    printf("\n[%sX%s] The system will now proceed to die\n", CRED, CRESET);

    va_end(args);

    while (true) {
        asm {
            cli;
            hlt;
        }
    }
}
