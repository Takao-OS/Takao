module services.terminal;

import scheduler.thread;
import stivale;
import lib.alloc;
import lib.bus;
import services.terminal.tty;

struct TerminalMessage {
    string contents;
}

__gshared MessageQueue!TerminalMessage terminalQueue;
private __gshared bool isInit;
private __gshared TTY* tty;

void terminalEarlyInit(StivaleFramebuffer fb) {
    tty = newObj!TTY(fb);
    tty.clear();
    isInit = true;
}

void terminalPrint(string str) {
    if (isInit) {
        tty.print(str);
    }
}

void terminalService(StivaleFramebuffer* fb) {
    // FIXME: Not a log() because that breaks the messaging system quite hard.
    terminalPrint("Started Terminal service\n");

    while (true) {
        auto msg = terminalQueue.receiveMessage();
        terminalPrint(msg.message.contents);
        terminalQueue.messageProcessed(msg);
    }
}
