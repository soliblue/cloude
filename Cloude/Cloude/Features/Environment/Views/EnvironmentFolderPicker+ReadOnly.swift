import SwiftUI

extension EnvironmentFolderPicker {
    var readOnlyContent: some View {
        HStack(spacing: DS.Spacing.s) {
            Image.safeSymbol(selectedEnv?.symbol ?? "server.rack")
                .font(.system(size: DS.Text.m))
                .foregroundColor(.accentColor)
            Text(selectedEnv?.host ?? "")
                .font(.system(size: DS.Text.m, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let dir = currentConversation.workingDirectory, !dir.isEmpty {
                Spacer()
                Text(dir)
                    .font(.system(size: DS.Text.m, design: .monospaced))
                    .foregroundColor(.secondary.opacity(DS.Opacity.l))
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .background(Color.themeSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l))
    }
}
