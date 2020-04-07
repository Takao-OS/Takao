module lib.messages;

import lib.bus;
import services.kmessage;

private void sendMessage(KMessagePriority priority, string message) {
    MessageQueue!(KMessage)* queue;

    while (queue == null) {
        queue = getMessageQueue!KMessage(KMESSAGE_SERVICE_NAME);    
    }

    queue.sendMessage(KMessage(priority, message));
}

void log(string message) {
    sendMessage(KMessagePriority.Log, message);
}

void warn(string message) {
    sendMessage(KMessagePriority.Warn, message);
}

void error(string message) {
    sendMessage(KMessagePriority.Error, message);
}
