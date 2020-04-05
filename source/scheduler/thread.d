module scheduler.thread;

import system.gdt;
import system.intrinsics;
import memory.physical;
import memory.virtual;
import lib.spinlock;

struct Thread {
    bool      present;
    int       id;
    Registers regs;
}

private __gshared Spinlock    lock;
private __gshared int         currentThread = -1;
private __gshared Thread*[32] runningQueue;
private __gshared Thread*[32] idleQueue;
private __gshared Thread[64]  threadPool;

extern (C) void schedulerTick(Registers* regs) {
    if (!lock.acquireOrFail()) {
        return;
    }

    if (currentThread != -1) {
        threadPool[currentThread].regs = *regs;
    }
    
    currentThread = getNextThread(currentThread);

    if (currentThread == -1) {
        lock.release();
        for (;;) {
            asm { hlt; }
        }
    }

    lock.release();
    loadThread(&(threadPool[currentThread].regs));
}

private extern(C) void loadThread(Registers* regs) {
    asm {
        naked;

        mov RSP, RDI;
        pop R15;
        pop R14;
        pop R13;
        pop R12;
        pop R11;
        pop R10;
        pop R9;
        pop R8;
        pop RBP;
        pop RDI;
        pop RSI;
        pop RDX;
        pop RCX;
        pop RBX;
        pop RAX;
        iretq;
    }
}

private int getNextThread(int currentThread) {
    int t = currentThread + 1;
    for (int i = 0; i < runningQueue.length + 1; i++, t++) {
        if (t == runningQueue.length) {
            t = 0;
        }
        if (runningQueue[t] != null) {
            return runningQueue[t].id;
        }
    }

    return -1;
}

int spawnThread(T)(void* entry, T arg) {
    lock.acquire();

    auto id     = getFreeThread();
    auto thread = &threadPool[id];

    thread.regs.rsp    = cast(size_t)(allocPageAndZero() + PAGE_SIZE + MEM_PHYS_OFFSET);
    thread.regs.rip    = cast(size_t)entry;
    thread.regs.rdi    = cast(size_t)arg;
    thread.regs.cs     = CODE_SEGMENT;
    thread.regs.ss     = DATA_SEGMENT;
    thread.regs.rflags = 0x202;
    thread.present     = true;
    thread.id          = id;

    queueThread(id);

    lock.release();
    return id;
}

private int getFreeThread() {
    foreach (int i; 0..threadPool.length) {
        if (!threadPool[i].present) {
            return i;
        }
    }

    return -1;
}

private void queueThread(int thread) {
    foreach (int i; 0..runningQueue.length) {
        if (runningQueue[i] == null) {
            runningQueue[i] = &threadPool[thread];
            return;
        }
    }
}
