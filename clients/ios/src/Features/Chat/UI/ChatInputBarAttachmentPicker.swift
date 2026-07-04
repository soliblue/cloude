import PhotosUI
import SwiftUI

struct ChatInputBarAttachmentPicker: View {
    let sessionId: UUID
    @Binding var images: [Data]
    @State private var selections: [PhotosPickerItem] = []
    @Environment(\.theme) private var theme

    var body: some View {
        PhotosPicker(selection: $selections, maxSelectionCount: 4, matching: .images) {
            Text(Image(systemName: "paperclip"))
                .appFont(size: ThemeTokens.Text.l, weight: .medium)
                .foregroundColor(.secondary)
                .padding(ThemeTokens.Spacing.m)
                .contentShape(Capsule())
        }
        .onChange(of: selections) { _, items in
            Task {
                var loaded: [Data] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        loaded.append(data)
                    }
                }
                let failed = items.count - loaded.count
                await MainActor.run {
                    images.append(contentsOf: loaded)
                    selections = []
                    if failed > 0 {
                        SessionToastStore.shared.present(
                            SessionToast(
                                sessionId: sessionId,
                                title: failed == 1 ? "An image couldn't be added"
                                    : "\(failed) images couldn't be added",
                                symbol: "exclamationmark.triangle.fill",
                                snippet: "They may be in an unsupported format."))
                    }
                }
            }
        }
    }
}
