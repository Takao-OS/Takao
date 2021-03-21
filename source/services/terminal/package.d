module services.terminal;

import scheduler.thread;
import stivale2;
import lib.alloc;
import lib.bus;
import services.terminal.tty;

struct TerminalMessage {
    string contents;
}

__gshared MessageQueue!TerminalMessage terminalQueue;

private void printMessage(string msg) {
import system.cpu;
    foreach (c; msg) {
        // Qemu.
        outb(0xe9, c);
    }
}

void terminalService(Stivale2Framebuffer* fb) {
    assert(fb != null);

    auto tty = newObj!TTY(fb);
    tty.clear();
    tty.print("Started Terminal service\n");

    while (true) {
        auto msg = terminalQueue.receiveMessage();
        tty.print(msg.message.contents);
        terminalQueue.messageProcessed(msg);
    }
}
