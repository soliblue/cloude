import PhotosUI
import SwiftUI

struct ChatInputBarAttachmentPicker: View {
    @Binding var images: [Data]
    @State private var selections: [PhotosPickerItem] = []
    @Environment(\.theme) private var theme

    var body: some View {
        PhotosPicker(selection: $selections, maxSelectionCount: 4, matching: .images) {
            Image(systemName: "paperclip.circle.fill")
                .appFont(size: ThemeTokens.Icon.xl)
                .foregroundColor(.secondary)
        }
        .onChange(of: selections) { _, items in
            Task {
                var loaded: [Data] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        loaded.append(data)
                    }
                }
                await MainActor.run {
                    images.append(contentsOf: loaded)
                    selections = []
                }
            }
        }
    }
}
