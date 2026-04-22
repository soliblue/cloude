import SwiftData
import SwiftUI

struct FolderPickerView: View {
    let session: Session
    let endpoint: Endpoint
    let path: String
    let title: String
    let onPick: ((String) -> Void)?

    @Environment(\.theme) private var theme
    @State private var folders: [FileNodeDTO] = []
    @State private var resolvedPath: String?

    var body: some View {
        Group {
            if let resolvedPath {
                List(folders, id: \.path) { folder in
                    NavigationLink(value: folder) {
                        HStack(spacing: ThemeTokens.Spacing.s) {
                            Image(systemName: "folder.fill")
                                .appFont(size: ThemeTokens.Icon.m)
                                .foregroundColor(ThemeColor.blue)
                            Text(folder.name)
                                .appFont(size: ThemeTokens.Text.m)
                        }
                    }
                    .listRowBackground(theme.palette.surface)
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .toolbar {
                    if let onPick {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                onPick(resolvedPath)
                            } label: {
                                Image(systemName: "checkmark")
                                    .appFont(size: ThemeTokens.Text.m, weight: .medium)
                            }
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: FileNodeDTO.self) { folder in
            FolderPickerView(
                session: session,
                endpoint: endpoint,
                path: folder.path,
                title: folder.name,
                onPick: onPick
            )
        }
        .task {
            let listing = await FilesService.list(endpoint: endpoint, session: session, path: path)
            folders = listing?.entries.filter { $0.isDirectory } ?? []
            resolvedPath = listing?.path ?? path
        }
    }
}
