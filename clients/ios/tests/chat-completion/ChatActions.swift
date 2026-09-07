enum ChatActions {
    static func finishStreaming(_ message: ChatMessage, isFailed: Bool) {
        message.state = isFailed ? .failed : .complete
    }
}
