import Foundation
import SwiftUI

@Observable
final class FilePreviewPresenter {
    var target: Target?

    func open(session: Session, path: String) {
        let name = (path as NSString).lastPathComponent
        let node = FileNodeDTO(
            name: name, path: path, isDirectory: false,
            size: nil, modifiedAt: nil, mimeType: nil
        )
        target = Target(session: session, node: node)
    }

    struct Target: Identifiable {
        let session: Session
        let node: FileNodeDTO
        var id: String { "\(session.id.uuidString):\(node.path)" }
    }
}

private struct FilePreviewPresenterKey: EnvironmentKey {
    static let defaultValue = FilePreviewPresenter()
}

extension EnvironmentValues {
    var filePreviewPresenter: FilePreviewPresenter {
        get { self[FilePreviewPresenterKey.self] }
        set { self[FilePreviewPresenterKey.self] = newValue }
    }
}
