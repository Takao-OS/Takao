module services.kmessage;

import scheduler.thread;
import lib.bus;
import lib.messages;

private immutable CCYAN    = "\033[36m";
private immutable CMAGENTA = "\033[35m";
private immutable CRED     = "\033[31m";
private immutable CRESET   = "\033[0m";

enum KMessagePriority {
    Log,
    Warn,
    Error
}

struct KMessage {
    KMessagePriority priority;
    string           contents;
}

__gshared MessageQueue!KMessage kmessageQueue;

void kmessageService(void* unused) {
    kmessageQueue.setReceiverThread(currentThread);
    kmessageQueue.sendMessageAsync(KMessage(KMessagePriority.Log,
                                   "Started KMessage service"));

    while (true) {
        auto msg = kmessageQueue.receiveMessage();

        final switch (msg.message.priority) {
            case KMessagePriority.Log:
                qemuPrintMsg(CCYAN);
                break;
            case KMessagePriority.Warn:
                qemuPrintMsg(CMAGENTA);
                break;
            case KMessagePriority.Error:
                qemuPrintMsg(CRED);
                break;
        }

        qemuPrintMsg(">> ");
        qemuPrintMsg(CRESET);
        qemuPrintMsg(msg.message.contents);
        qemuPrintMsg("\n");

        kmessageQueue.messageProcessed(msg);
    }
}

private void qemuPrintMsg(string msg) {
    foreach (c; msg) {
        asm {
            mov AL,   c;
            out 0xE9, AL;
        }
    }
}
