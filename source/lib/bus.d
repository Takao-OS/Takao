module lib.bus;

import lib.lock;
import scheduler.thread;
import lib.debugging;

struct MessageQueue(T) {
    private string name;
    private Lock   lock;
    private int    threadId;
    private int    queueIndex;

    struct QueueElem {
        T   message;
        int senderThread;
    }

    private QueueElem[256] queue;

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

    QueueElem receiveMessage() {
        this.lock.acquire();

        while (queueIndex == 0) {
            // There are no messages to read, yield.
            this.lock.release();
            dequeueAndYield();
            this.lock.acquire();
        }

        auto ret = queue[0];

        queueIndex--;
        foreach (int i; 0..queueIndex) {
            queue[i] = queue[i+1];
        }

        this.lock.release();
        return ret;
    }

    void messageProcessed(QueueElem elem) {
        if (elem.senderThread != -1) {
            queueThreadOrWait(elem.senderThread);
        }
    }

    private int queueMessage(T)(T message, int senderThread) {
        if (queueIndex == queue.length) {
            return -1;
        }

        queue[queueIndex].message      = message;
        queue[queueIndex].senderThread = senderThread;

        queueIndex++;

        queueThread(this.threadId);
        return 0;
    }

    int sendMessageAsync(T)(T message) {
        this.lock.acquire();

        auto ret = queueMessage(message, -1);

        this.lock.release();
        return ret;
    }

    int sendMessageSync(T)(T message) {
        this.lock.acquire();

        auto ret = queueMessage(message, currentThread);
        if (ret) {
            this.lock.release();
            return ret;
        }

        this.lock.release();
        dequeueAndYield();

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
