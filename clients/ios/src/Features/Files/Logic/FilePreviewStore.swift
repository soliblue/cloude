import Foundation
import Observation

@Observable
final class FilePreviewStore {
    var resource: FilePreviewResource?
    var failed = false
    var attempt = 0
}
