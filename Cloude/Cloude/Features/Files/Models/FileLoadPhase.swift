import Foundation
import CloudeShared

enum FileLoadPhase {
    case loading
    case loaded
    case thumbnail(fullSize: Int64, isLoadingFull: Bool)
    case directory([FileEntry])
    case error(String)
}
