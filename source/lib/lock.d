/// Lock library.
module lib.lock;

import core.atomic: cas, atomicStore;

private immutable ubyte spinlockLocked   = 1;
private immutable ubyte spinlockUnlocked = 0;

/// Object representing a lock.
shared struct Lock {
    private shared ubyte status;

    /// Acquire the lock, which will not allow any other user to acquire
    /// until release.
    void acquire() {
        while (true) {
            if (cas(&status, spinlockUnlocked, spinlockLocked)) {
                return;
            }

            // CPU optimisation (would put 'pause' but D doesnt support it).
            asm { rep; nop; }
        }
    }

    /// Try to acquire the lock, return `true` if acquired, or return `false`
    /// if failed.
    bool acquireOrFail() {
        return cas(&status, spinlockUnlocked, spinlockLocked);
    }

    /// Set the lock to unlocked.
    void release() {
        atomicStore(status, spinlockUnlocked);
    }
}
