import Foundation

final class TranscriptionOperation<Value> {
    private let condition = NSCondition()
    private var finished = false
    private var value: Value?
    private var cancellation: (() -> Void)?

    func finish(_ value: Value?) {
        condition.lock()
        if !finished {
            self.value = value
            finished = true
            condition.broadcast()
        }
        condition.unlock()
    }

    func setCancellation(_ cancellation: @escaping () -> Void) {
        condition.lock()
        let alreadyFinished = finished
        if !alreadyFinished { self.cancellation = cancellation }
        condition.unlock()
        if alreadyFinished { cancellation() }
    }

    func wait(timeout: TimeInterval) -> Value? {
        condition.lock()
        let deadline = Date().addingTimeInterval(timeout)
        while !finished, condition.wait(until: deadline) {}
        finished = true
        let value = value
        let cancellation = cancellation
        self.cancellation = nil
        condition.unlock()
        cancellation?()
        return value
    }
}
