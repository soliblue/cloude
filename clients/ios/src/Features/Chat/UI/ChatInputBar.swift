import SwiftData
import SwiftUI

struct ChatInputBar: View {
    let session: Session
    var enabled: Bool = true
    var onSend: (String, [Data]) -> Void
    @State private var draft: String = ""
    @State private var images: [Data] = []
    @FocusState private var focused: Bool
    @Environment(\.appAccent) private var appAccent
    @Environment(\.modelContext) private var context

    init(session: Session, enabled: Bool = true, onSend: @escaping (String, [Data]) -> Void) {
        self.session = session
        self.enabled = enabled
        self.onSend = onSend
        PerfCounters.bumpInit("ib")
    }

    var body: some View {
        let _ = PerfCounters.bump("ib.body")
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
                if session.isStreaming {
                    Button {
                        ChatService.abort(session: session, context: context)
                    } label: {
                        Text(Image(systemName: "stop.fill"))
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                            .foregroundColor(appAccent.color)
                            .padding(ThemeTokens.Spacing.m)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Capsule())
                } else {
                    Menu {
                        sendMenu
                    } label: {
                        Text(Image(systemName: "paperplane.fill"))
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
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .padding(.bottom, focused ? ThemeTokens.Spacing.xl : 0)
        .animation(.easeInOut(duration: ThemeTokens.Duration.s), value: focused)
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
            focused = false
        }
    }

    private var canSend: Bool {
        enabled && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty)
    }
}
