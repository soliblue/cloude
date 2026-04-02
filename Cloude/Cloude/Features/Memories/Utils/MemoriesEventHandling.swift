import Foundation
import CloudeShared

extension App {
    func handleMemories(sections: [MemorySection]) {
        memoriesStore.handle(sections: sections)
    }
}
