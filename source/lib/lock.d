module lib.lock;

import core.atomic: cas, atomicStore;

private immutable ubyte spinlockLocked   = 1;
private immutable ubyte spinlockUnlocked = 0;

/// Spinlock.
struct Lock {
    private shared ubyte status = spinlockUnlocked;

    /// Acquire the lock, and loop forever until locked.
    void acquire() {
        while (true) {
            if (cas(&status, spinlockUnlocked, spinlockLocked)) {
                return;
            }
        }
    }

    /// Acquire the lock, or return false if not locked.
    bool acquireOrFail() {
        return cas(&status, spinlockUnlocked, spinlockLocked);
    }

    /// Release a lock unconditionally.
    void release() {
        atomicStore(status, spinlockUnlocked);
    }
}
