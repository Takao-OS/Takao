/// The panic function, used for interrupting the kernel when something
/// nasty happens.
module lib.panic;

import lib.lock: Lock;

private shared Lock panicLock;

/// The exit button. Killing the OS.
/// Params:
///     args = Messages to print as the panic reason.
void panic(T...)(T args) {
    import lib.string:   buildStringInPlace, fromCString;
    import wm.driver:    showPanicScreen;
    debug import lib.debugtools: error;

    // Allow only 1 callee to panic at once.
    panicLock.acquire();

    // Build the error message.
    char[128] buffer;
    auto ret = buildStringInPlace(buffer.ptr, buffer.length, args);
    auto str = fromCString(buffer.ptr, ret);

    /// Error and lock forever.
    showPanicScreen(str);
    debug error(str);
    while (true) {
        asm {
            cli;
            hlt;
        }
    }
}
