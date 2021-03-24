/// The panic function, used for interrupting the kernel when something
/// nasty happens.
module lib.panic;

import lib.lock: Lock;

private __gshared Lock panicLock;

/// The exit button. Kills all cores, forever, always.
/// It's a killing machine.
/// Params:
///     msg = Message to print as the panic reason, not null.
void panic(T...)(T args) {
    import display.wm:    panicScreen;
    import archinterface: killCore, executeCore, getCoreCount, getCurrentCore, disableInterrupts;
    import lib.string:    buildStringInPlace, fromCString;
    debug import lib.debugtools: error;

    panicLock.acquire();

    // Halt everything.
    const current = getCurrentCore();
    foreach (i; 0..getCoreCount()) {
        if (i != current) {
            executeCore(i, () {
                disableInterrupts();
                killCore();
            });
            debug error("Killed core #", i);
        }
    }

    char[128] buffer;
    auto ret = buildStringInPlace(buffer.ptr, buffer.length, "Core ", current, ": ", args);
    auto str = fromCString(buffer.ptr, ret);

    // Display panic with all means we have and die.
    disableInterrupts();
    panicScreen(str);
    debug error(str);
    killCore();
}
