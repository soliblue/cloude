import Foundation

@main
struct DaemonLifecycleTests {
    static func main() {
        let lifecycle = DaemonLifecycle()
        let admission = lifecycle.begin()!
        precondition(!lifecycle.reserveUpdate())
        lifecycle.end(admission)
        precondition(lifecycle.reserveUpdate())
        precondition(lifecycle.begin() == nil)
        var committed = false
        precondition(lifecycle.commitUpdate { committed = true })
        precondition(committed)
        lifecycle.releaseUpdate()
        let retry = lifecycle.begin()!
        lifecycle.end(retry)
        precondition(lifecycle.reserveUpdate())
        let observed = lifecycle.observeWork()
        precondition(!lifecycle.commitUpdate { preconditionFailure("work arrived before shutdown") })
        precondition(!lifecycle.reserveUpdate())
        lifecycle.end(observed)
        let queue = DispatchQueue(label: "lifecycle-test.count")
        var rejected = 0
        var successful = 0
        precondition(lifecycle.reserveUpdate())
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            if lifecycle.begin() == nil { queue.sync { rejected += 1 } }
        }
        precondition(rejected == 100)
        lifecycle.releaseUpdate()
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            if let id = lifecycle.begin() {
                queue.sync { successful += 1 }
                lifecycle.end(id)
            }
        }
        precondition(successful == 100)
        precondition(lifecycle.reserveUpdate())
        lifecycle.releaseUpdate()
        print(
            "Native lifecycle: concurrent admission fencing, active-work reservation rejection, observed-work cancellation, atomic commit and failure recovery passed"
        )
    }
}
