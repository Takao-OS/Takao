module services.kmessage;

import scheduler.thread;
import lib.bus;
import lib.messages;
import services.terminal;

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
    kmessageQueue.sendMessageAsync(KMessage(KMessagePriority.Log,
                                   "Started KMessage service"));
    while (true) {
        auto msg = kmessageQueue.receiveMessage();

        final switch (msg.message.priority) {
            case KMessagePriority.Log:
                printMessage(CCYAN);
                break;
            case KMessagePriority.Warn:
                printMessage(CMAGENTA);
                break;
            case KMessagePriority.Error:
                printMessage(CRED);
                break;
        }

        printMessage(">> ");
        printMessage(CRESET);
        printMessage(msg.message.contents);
        printMessage("\n");

        kmessageQueue.messageProcessed(msg);
    }
}

private void printMessage(string msg) {
    foreach (c; msg) {
        // Qemu.
        asm {
            mov AL,   c;
            out 0xE9, AL;
        }
    }

    // Terminal.
    terminalQueue.sendMessageAsync(TerminalMessage(msg));
}
