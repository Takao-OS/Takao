module lib.bus;

import lib.lock;
import scheduler.thread;

struct MessageQueue(T) {
    private Lock lock;
    private int  threadId = -1;
    private int  queueIndex;

    struct QueueElem {
        T   message;
        int senderThread;
    }

    private QueueElem[256] queue;

    QueueElem receiveMessage() {
        this.lock.acquire();

        threadId = currentThread;

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

        if (this.threadId != -1) {
            queueThread(this.threadId);
        }

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
