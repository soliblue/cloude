import SwiftUI

extension MainChatView {
    func windowHeader(for window: ChatWindow, conversation: Conversation?) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(WindowType.allCases.enumerated()), id: \.element) { index, type in
                let envConnected = type == .chat || (conversation?.environmentId).flatMap({ connection.connection(for: $0)?.isConnected }) ?? false
                if index > 0 {
                    Divider()
                        .frame(height: 20)
                }
                Button(action: {
                    if envConnected { windowManager.setWindowType(window.id, type: type) }
                }) {
                    Image(systemName: type.icon)
                        .font(.system(size: DS.Icon.tab, weight: window.type == type ? .semibold : .regular))
                        .foregroundColor(window.type == type ? .accentColor : .secondary)
                        .opacity(envConnected ? 1 : 0.3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

        }
        .padding(.horizontal, 7)
        .padding(.top, 0)
        .padding(.bottom, 7)
        .background(Color.themeSecondary)
    }
}
