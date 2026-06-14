import Foundation
import Network

protocol ChatRunning: AnyObject {
    var hasExited: Bool { get }
    var onFinish: (() -> Void)? { get set }
    func subscribe(_ connection: NWConnection, afterSeq: Int)
    func abort()
}
