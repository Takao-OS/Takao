/// Tools for debugging on debug builds.
module lib.debugtools;

debug import archinterface: debugPrintChar;

debug {
    import archinterface: debugPrintChar;
    import lib.lock:      Lock;

    private __gshared Lock printLock;

    private enum MessageType {
        Log,
        Warn,
        Error
    }

    private immutable CONVERSION_TABLE = "0123456789abcdef";

    /// Log a debug message.
    void log(T...)(T form) {
        innerprint(MessageType.Log, form);
    }

    /// Print a warning.
    void warn(T...)(T form) {
        innerprint(MessageType.Warn, form);
    }

    /// Print an error.
    void error(T...)(T form) {
        innerprint(MessageType.Error, form);
    }

    private void innerprint(T...)(MessageType type, T items) {
        import lib.string: buildStringInPlace, fromCString;

        printLock.acquire();
        final switch (type) {
            case MessageType.Log:
                print("\033[36mLOG\033[0m: ");
                break;
            case MessageType.Warn:
                print("\033[35mWARN\033[0m: ");
                break;
            case MessageType.Error:
                print("\033[31mERROR\033[0m: ");
                break;
        }

        char[128] buffer;
        auto ret = buildStringInPlace(buffer.ptr, buffer.length, items);
        print(fromCString(buffer.ptr, ret));
        print('\n');
        printLock.release();
    }

    private void print(ubyte add) {
        print(cast(size_t)add);
    }

    private void print(char c) {
        debugPrintChar(c);
    }

    private void print(string add) {
        foreach (c; add) {
            debugPrintChar(c);
        }
    }

    private void print(void* addr) {
        print(cast(size_t)addr);
    }

    private void print(size_t x) {
        import lib.string: fromCString;

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
        print(fromCString(&buf[i]));
    }
}
