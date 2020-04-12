module services.terminal;

import scheduler.thread;
import lib.stivale;
import lib.alloc;
import lib.bus;
import services.terminal.tty;

struct TerminalMessage {
    string contents;
}

__gshared MessageQueue!TerminalMessage terminalQueue;

void terminalService(StivaleFramebuffer* fb) {
    auto tty = TTY(*fb);
    tty.clear();

    // FIXME: Not a log() because that breaks the messaging system quite hard.
    tty.print("Started Terminal service\n");

    while (true) {
        auto msg = terminalQueue.receiveMessage();
        tty.print(msg.message.contents);
        terminalQueue.messageProcessed(msg);
    }
}
