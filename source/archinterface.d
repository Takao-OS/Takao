/// Functions and structures to abstract ports.
module archinterface;

debug {
    /// Output a character to an architecture specific debug output.
    /// Params:
    ///     c = Char to print.
    void debugPrintChar(char c) {
        import arch.x86_64_stivale2.cpu: outb;
        outb(0xe9, c);
    }
}

/// Enables interruptions for the current core.
void enableInterrupts() {
    asm { sti; }
}

/// Disables interruptions for the current core.
void disableInterrupts() {
    asm { cli; }
}

/// Makes a core sleep by at least the passed ammount of miliseconds.
/// Params:
///     msecs = Miliseconds to sleep.
void sleep(size_t msec) {
    import arch.x86_64_stivale2.pit: pitsleep = sleep;
    pitsleep(msec);
}

/// Registers a function as an interrupt for all CPUs.
/// Params:
///     num = Number of interrupt to use, if possible, size_t.max for up to the
///           function to decide.
///     func = Function to use for the interrupt, not null.
/// Returns: The allocated interrupt number, or size_t.max in failure.
size_t registerGlobalInterrupt(size_t num, void function() func) {
    import arch.x86_64_stivale2.idt: addInterrupt, Handler;

    assert(func != null);

    if (num != size_t.max) {
        addInterrupt(cast(uint)num, cast(Handler)func, false);
        return num;
    } else {
        // TODO: Support arbitrary interrupt allocation.
        return size_t.max;
    }
}

/// Enables or disables an interrupt reception in the current CPU.
/// Params:
///     num    = Number of interrupt to modify.
///     enable = True to enable, false to disable.
void maskCoreInterrupt(size_t num, bool enable) {
    import arch.x86_64_stivale2.apic: ioAPICSetUpLegacyIRQ;
    ioAPICSetUpLegacyIRQ(cast(int)getCurrentCore(), cast(ubyte)num, enable);
}

/// Get core count of the system, including the current core.
/// Returns: At least 1 (for obvious reasons).
size_t getCoreCount() {
    import arch.x86_64_stivale2.smp: cpuCount;
    return cpuCount;
}

/// Get current core number.
/// Returns: 0-based core number.
size_t getCurrentCore() {
    import arch.x86_64_stivale2.cpu: currentCPU;
    return currentCPU();
}

/// Drive the current core into an unrecoverable state.
void killCore() {
    while (true) {
        asm {
            cli;
            hlt;
        }
    }
}

/// Make the passed core execute code starting from the passed function.
/// Any kind of state is not to be assumed preserved, and its not safe to let
/// the core return from the function.
/// Params:
///     core = Core to override execution from.
///     func = Function to execute, not null.
void executeCore(size_t core, void function() func) {
    import arch.x86_64_stivale2.apic: lapicSendIPI;
    import arch.x86_64_stivale2.cpu:  cpuLocals;

    assert(func != null);

    cpuLocals[core].execLock.acquire();
    cpuLocals[core].exec = func;
    cpuLocals[core].execLock.release();
    lapicSendIPI(cast(int)core, 0xcc);
}
