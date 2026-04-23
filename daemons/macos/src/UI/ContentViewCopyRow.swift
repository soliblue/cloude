import SwiftUI

struct ContentViewCopyRow: View {
    let label: String
    let value: String
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: copy) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isCopied ? Color.green : .secondary)
                        .contentTransition(.opacity)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isCopied = false }
        }
    }
}
