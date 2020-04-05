module lib.lock;

import core.atomic;

private immutable ubyte SPINLOCK_LOCKED   = 1;
private immutable ubyte SPINLOCK_UNLOCKED = 0;

struct Lock {
    private shared ubyte status;

    void acquire() {
        while (true) {
            if (cas(&(this.status), SPINLOCK_UNLOCKED, SPINLOCK_LOCKED)) {
                return;
            }

            // CPU optimisation (would put 'pause' but D doesnt support it).
            asm { rep; nop; }
        }
    }
    
    bool acquireOrFail() {
        return cas(&(this.status), SPINLOCK_UNLOCKED, SPINLOCK_LOCKED);
    }

    void release() {
        atomicStore(this.status, SPINLOCK_UNLOCKED);
    }
}
