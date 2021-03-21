module lib.messages;

import services.kmessage;
import services.terminal;
import main;
import system.cpu;
import lib.string;

void log(T...)(T form) {
    innerPrint(KMessagePriority.Log, form);
}

void warn(T...)(T form) {
    innerPrint(KMessagePriority.Warn, form);
}

void error(T...)(T form) {
    innerPrint(KMessagePriority.Error, form);
}

private void innerPrint(T...)(KMessagePriority priority, T args) {
    if (servicesUp) {
        auto ret = buildString(args);
        auto msg = KMessage(priority, ret);
        kmessageQueue.sendMessageSync(msg);
    } else {
        char[128] buffer;
        auto ret = buildStringInPlace(buffer.ptr, buffer.length, args);
        auto str = fromCString(buffer.ptr, ret);
        final switch (priority) {
            case KMessagePriority.Log:
                print("LOG: ");
                break;
            case KMessagePriority.Warn:
                print("WARN: ");
                break;
            case KMessagePriority.Error:
                print("ERROR: ");
                break;
        }

        print(str);
        print("\n");
    }
}

private void print(string str) {
    foreach (c; str) {
        outb(0xe9, c);
    }
}
