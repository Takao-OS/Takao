module services.kmessage;

import lib.bus;
import lib.messages;
import services.terminal;
import system.cpu;

private immutable colorCyan    = "\033[36m";
private immutable colorMagenta = "\033[35m";
private immutable colorRed     = "\033[31m";
private immutable colorReset   = "\033[0m";

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
                printMessage(colorCyan);
                break;
            case KMessagePriority.Warn:
                printMessage(colorMagenta);
                break;
            case KMessagePriority.Error:
                printMessage(colorRed);
                break;
        }

        printMessage(">> ");
        printMessage(colorReset);
        printMessage(msg.message.contents);
        printMessage("\n");

        kmessageQueue.messageProcessed(msg);
    }
}

private void printMessage(string msg) {
    foreach (c; msg) {
        // Qemu.
        outb(0xe9, c);
    }

    // Terminal.
    terminalQueue.sendMessageSync(TerminalMessage(msg));
}
