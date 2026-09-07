import SwiftUI

struct SessionProjectRootButton: View {
    let session: Session
    let endpoint: Endpoint
    let project: SessionProject
    let root: SessionProjectRoot
    let onPick: () -> Void

    var body: some View {
        Button {
            SessionActions.setProject(project, root: root, endpoint: endpoint, for: session)
            onPick()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.displayName).font(.body)
                    Text(root.path).font(.caption.monospaced()).foregroundStyle(.secondary)
                        .lineLimit(2).truncationMode(.middle)
                }
                Spacer()
                if session.codexProjectId == project.id && session.path == root.path {
                    Image(systemName: "checkmark").accessibilityLabel("Selected")
                }
            }
        }
        .accessibilityLabel("\(project.displayName), \(root.path)")
    }
}
