module lib.messages;

import services.kmessage;

private void sendMessage(KMessagePriority priority, string message) {
    kmessageQueue.sendMessageSync(KMessage(priority, message));
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
