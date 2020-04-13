module scheduler.thread;

import system.gdt;
import system.cpu;
import memory.physical;
import memory.virtual;
import lib.lock;
import lib.messages;

struct Thread {
    bool      present;
    int       id;
    bool      isRunning;
    int       runningQueueIndex;
    Registers regs;
}

__gshared         int         currentThread = -1;

private __gshared Lock        schedulerEnableLock;
private __gshared Lock        schedulerLock;
private __gshared Thread*[32] runningQueue;
private __gshared Thread[64]  threadPool;

void disableScheduler() {
    schedulerEnableLock.acquire();
}

void enableScheduler() {
    schedulerEnableLock.release();
}

extern (C) void reschedule(Registers* regs) {
    if (!schedulerEnableLock.acquireOrFail()) {
        return;
    }

    schedulerLock.acquire();

    if (currentThread != -1) {
        threadPool[currentThread].regs = *regs;
        currentThread = getNextThread(threadPool[currentThread].runningQueueIndex + 1);
    } else {
        currentThread = getNextThread(0);
    }

    if (currentThread == -1) {
        schedulerLock.release();
        schedulerEnableLock.release();
        for (;;) {
            asm { sti; hlt; }
        }
    }

    schedulerLock.release();
    schedulerEnableLock.release();
    loadThread(&(threadPool[currentThread].regs));
}

private extern (C) void loadThread(Registers* regs) {
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

void dequeueAndYield() {
    schedulerLock.acquire();

    // We don't wanna be interrupted
    asm { cli; }

    int runningQueueIndex = threadPool[currentThread].runningQueueIndex;
    runningQueue[runningQueueIndex] = null;

    threadPool[currentThread].isRunning = false;

    schedulerLock.release();

    yield();
}

extern (C) void yield() {
    asm {
        naked;

        cli;

        mov RAX, RSP;
        push DATA_SEGMENT;
        push RAX;
        push 0x202;
        push CODE_SEGMENT;
        lea RAX, L2;
        push RAX;
        push RAX;
        push RBX;
        push RCX;
        push RDX;
        push RSI;
        push RDI;
        push RBP;
        push R8;
        push R9;
        push R10;
        push R11;
        push R12;
        push R13;
        push R14;
        push R15;

    L1:
        mov RDI, RSP;
        call reschedule;
        jmp L1;

    L2:
        ret;
    }
}

private int getNextThread(int baseQueueIndex) {
    foreach (int i; 0..(runningQueue.length + 1)) {
        if (baseQueueIndex >= runningQueue.length) {
            baseQueueIndex = 0;
        }
        if (runningQueue[baseQueueIndex] != null) {
            return runningQueue[baseQueueIndex].id;
        }
        baseQueueIndex++;
    }

    return -1;
}

int spawnThread(T)(void* entry, T arg) {
    schedulerLock.acquire();

    auto id     = getFreeThread();
    auto thread = &threadPool[id];

    thread.regs.rsp    = cast(size_t)(pmmAllocAndZero(1) + PAGE_SIZE + MEM_PHYS_OFFSET);
    thread.regs.rip    = cast(size_t)entry;
    thread.regs.rdi    = cast(size_t)arg;
    thread.regs.cs     = CODE_SEGMENT;
    thread.regs.ss     = DATA_SEGMENT;
    thread.regs.rflags = 0x202;
    thread.present     = true;
    thread.id          = id;

    schedulerLock.release();

    queueThread(id);

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

private int innerQueueThread(int thread) {
    foreach (int i; 0..runningQueue.length) {
        if (runningQueue[i] == null) {
            runningQueue[i] = &threadPool[thread];
            threadPool[thread].runningQueueIndex = i;
            threadPool[thread].isRunning         = true;
            return 0;
        }
    }

    return -1;
}

int queueThreadOrWait(int thread) {
    schedulerLock.acquire();

    while (threadPool[thread].isRunning) {
        schedulerLock.release();
        yield();
        schedulerLock.acquire();
    }

    auto ret = innerQueueThread(thread);

    schedulerLock.release();
    return ret;
}

int queueThread(int thread) {
    schedulerLock.acquire();

    if (threadPool[thread].isRunning) {
        schedulerLock.release();
        return 0;
    }

    auto ret = innerQueueThread(thread);

    schedulerLock.release();
    return ret;
}
