import SwiftUI

struct ChatInputBar: View {
    let session: Session
    var enabled: Bool = true
    var onSend: (String, [Data]) -> Void
    @State private var draft: String = ""
    @State private var images: [Data] = []
    @FocusState private var focused: Bool
    @Environment(\.appAccent) private var appAccent

    var body: some View {
        VStack(spacing: ThemeTokens.Spacing.xs) {
            if !images.isEmpty {
                ChatInputBarAttachmentStrip(images: $images)
            }
            HStack(alignment: .bottom, spacing: ThemeTokens.Spacing.s) {
                ChatInputBarAttachmentPicker(images: $images)
                TextField("Message", text: $draft, axis: .vertical)
                    .appFont(size: ThemeTokens.Text.m)
                    .lineLimit(1...6)
                    .focused($focused)
                    .padding(.horizontal, ThemeTokens.Spacing.m)
                    .padding(.vertical, ThemeTokens.Spacing.m)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
                Menu {
                    sendMenu
                } label: {
                    Text(Image(systemName: "arrow.up"))
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .foregroundColor(canSend ? appAccent.color : .secondary)
                        .padding(ThemeTokens.Spacing.m)
                        .contentShape(Capsule())
                } primaryAction: {
                    send()
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Capsule())
                .disabled(!enabled)
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
    }

    @ViewBuilder
    private var sendMenu: some View {
        Menu {
            Button {
                SessionActions.setModel(nil, for: session)
            } label: {
                Label("Auto", systemImage: session.model == nil ? "checkmark" : "")
            }
            ForEach(ChatModel.allCases, id: \.self) { model in
                Button {
                    SessionActions.setModel(model, for: session)
                } label: {
                    Label(model.displayName, systemImage: session.model == model ? "checkmark" : "")
                }
            }
        } label: {
            Label("Model: \(session.model?.displayName ?? "Auto")", systemImage: "cpu")
        }
        Menu {
            Button {
                SessionActions.setEffort(nil, for: session)
            } label: {
                Label("Default", systemImage: session.effort == nil ? "checkmark" : "")
            }
            ForEach(ChatEffort.allCases, id: \.self) { level in
                Button {
                    SessionActions.setEffort(level, for: session)
                } label: {
                    Label(level.displayName, systemImage: session.effort == level ? "checkmark" : "")
                }
            }
        } label: {
            Label("Effort: \(session.effort?.displayName ?? "Default")", systemImage: "brain.head.profile")
        }
    }

    private func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if canSend && (!trimmed.isEmpty || !images.isEmpty) {
            onSend(trimmed, images)
            draft = ""
            images = []
        }
    }

    private var canSend: Bool {
        enabled && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty)
    }
}
