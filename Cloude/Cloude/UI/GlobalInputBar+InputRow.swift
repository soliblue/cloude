import SwiftUI

extension GlobalInputBar {
    var placeholder: String {
        Self.placeholders[placeholderIndex % Self.placeholders.count]
    }

    var canSend: Bool {
        if environmentMismatch { return false }
        return !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachedImages.isEmpty || !attachedFiles.isEmpty
    }

    var inputRow: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                if inputText.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.secondary)
                        .id(placeholderIndex)
                        .transition(.opacity)
                }
                TextField("", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .foregroundColor(isSlashCommand ? .cyan : .primary)
                    .onSubmit { if canSend { onSend() } }
                    .id("inputField")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.themeSecondary.opacity(0.8))
            .offset(x: -horizontalSwipeOffset * 0.3)
            .opacity(1 - Double(min(horizontalSwipeOffset, Constants.swipeThreshold)) / Double(Constants.swipeThreshold) * 0.5)

            actionButton
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    func selectFile(_ file: String) {
        guard let atIndex = inputText.lastIndex(of: "@") else { return }
        let beforeAt = String(inputText[..<atIndex])
        inputText = beforeAt + file + " "
    }
}
