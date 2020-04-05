module lib.bus;

import lib.lock;
import scheduler.thread;
import lib.debugging;

struct MessageQueue(T) {
    private string name;
    private Lock   lock;
    private int    threadId;
    private int    queueIndex;
    private T[256] queue;

    this(string name) {
        foreach (int i; 0..registeredQueues.length) {
            if (registeredQueues[i] == null) {
                registeredQueues[i] = cast(void*)&this;
                this.name     = name;
                this.threadId = currentThread;
                return;
            }
        }

        panic("Cannot register queue \"%s\"", cast(char*)name);
    }

    T receiveMessage() {
        this.lock.acquire();

        while (queueIndex == 0) {
            // There are no messages to read, yield.
            this.lock.release();
            dequeueAndYield();
            this.lock.acquire();
        }

        T ret = queue[0];

        queueIndex--;
        foreach (int i; 0..queueIndex) {
            queue[i] = queue[i+1];
        }

        this.lock.release();
        return ret;
    }

    int sendMessage(T)(T message) {
        this.lock.acquire();

        if (queueIndex == queue.length) {
            this.lock.release();
            return -1;
        }

        queue[queueIndex++] = message;

        queueThread(this.threadId);

        this.lock.release();
        return 0;
    }
}

private __gshared void*[256] registeredQueues;

MessageQueue!(T)* getMessageQueue(T)(string queueName) {
    // Tranlate a server name into its thread ID.
    foreach (int i; 0..registeredQueues.length) {
        if (registeredQueues[i] != null) {
            MessageQueue!(T)* ret = cast(MessageQueue!(T)*)registeredQueues[i];
            if (ret.name == queueName) {
                return ret;
            }
        }
    }

    return null;
}
