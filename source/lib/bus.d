module lib.bus;

import lib.lock;
import scheduler.thread;

struct MessageQueue(T) {
    string   queueName;
    Lock     queueLock;
    int      queueThreadId;
    int      queueIndex;
    T[256]   queue;

    this(string name) {
        foreach (int i; 0..registeredQueues.length) {
            if (registeredQueues[i] == null) {
                registeredQueues[i] = cast(void*)&this;
                queueName     = name;
                queueThreadId = currentThread;
                return;
            }
        }
        // TODO tidy this up
        for (;;) {}
    }

    T receiveMessage() {
        queueLock.acquire();

        while (queueIndex == 0) {
            // There are no messages to read, yield.
            queueLock.release();
            dequeueAndYield();
            queueLock.acquire();
        }

        T ret = queue[0];

        queueIndex--;
        foreach (int i; 0..queueIndex) {
            queue[i] = queue[i+1];
        }

        queueLock.release();
        return ret;
    }

    int sendMessage(T)(T message) {
        queueLock.acquire();

        if (queueIndex == queue.length) {
            queueLock.release();
            return -1;
        }

        queue[queueIndex++] = message;

        queueThread(queueThreadId);

        queueLock.release();
        return 0;
    }
}

private __gshared void*[256] registeredQueues;

MessageQueue!(T)* getMessageQueue(T)(string queueName) {
    // Tranlate a server name into its thread ID.
    foreach (int i; 0..registeredQueues.length) {
        if (registeredQueues[i] != null) {
            MessageQueue!(T)* ret = cast(MessageQueue!(T)*)registeredQueues[i];
            if (ret.queueName == queueName) {
                return ret;
            }
        }
    }

    return null;
}
