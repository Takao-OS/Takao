module lib.debugtools;

import system.cpu;
import lib.string;

debug {
private enum KMessagePriority {
    Log, Warn, Error
}

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
    char[128] buffer;
    auto ret = buildStringInPlace(buffer.ptr, buffer.length, args);
    auto str = fromCString(buffer.ptr, ret);
    final switch (priority) {
        case KMessagePriority.Log:
            print("\033[36mLOG\033[0m: ");
            break;
        case KMessagePriority.Warn:
            print("\033[35mWARN\033[0m: ");
            break;
        case KMessagePriority.Error:
            print("\033[31mERROR\033[0m: ");
            break;
    }

    print(str);
    print("\n");
}

private void print(string str) {
    foreach (c; str) {
        outb(0xe9, c);
    }
}
}
