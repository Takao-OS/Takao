module services.terminal;

import scheduler.thread;
import lib.stivale;
import lib.alloc;
import lib.bus;
import lib.messages;
import services.terminal.tty;

struct TerminalMessage {
    string contents;
}

__gshared MessageQueue!TerminalMessage terminalQueue;

void terminalService(StivaleFramebuffer* fb) {
    terminalQueue.setReceiverThread(currentThread);
    log("Started Terminal service");

    auto tty = TTY(*fb);
    tty.clear();

    while (true) {
        auto msg = terminalQueue.receiveMessage();
        tty.print(msg.message.contents);
        terminalQueue.messageProcessed(msg);
    }
}
