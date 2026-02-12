import SwiftUI
import UIKit
import CloudeShared

extension MainChatView {
    @ViewBuilder
    func heartbeatWindowContent() -> some View {
        let convOutput = connection.output(for: Heartbeat.conversationId)

        VStack(spacing: 0) {
            heartbeatHeader(isRunning: convOutput.isRunning)

            HeartbeatChatView(
                conversationStore: conversationStore,
                connection: connection,
                inputText: $inputText,
                attachedImages: $attachedImages,
                isKeyboardVisible: isKeyboardVisible
            )
        }
    }

    func heartbeatHeader(isRunning: Bool) -> some View {
        let heartbeat = conversationStore.heartbeatConversation
        let hasCustomName = heartbeat.name != "Heartbeat"

        return HStack(spacing: 9) {
            Button(action: triggerHeartbeat) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isRunning ? .secondary : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isRunning ? Color.secondary.opacity(0.2) : Color.accentColor)
                    )
            }
            .disabled(isRunning)
            .buttonStyle(.plain)
            .padding(7)

            Spacer()

            HStack(spacing: 4) {
                if isRunning {
                    Text("Running...")
                        .foregroundColor(.orange)
                } else {
                    Text(conversationStore.heartbeatConfig.lastTriggeredDisplayText)
                }
                Text("•")
                    .foregroundColor(.secondary)
                if hasCustomName {
                    Image.safeSymbol(heartbeat.symbol)
                        .font(.system(size: 12))
                    Text(heartbeat.name)
                } else {
                    Text("Heartbeat")
                }
            }
            .font(.caption)
            .fontWeight(.medium)

            Spacer()

            HStack(spacing: 0) {
                Button(action: refreshHeartbeat) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isRunning ? .secondary.opacity(0.3) : .secondary)
                        .padding(7)
                }
                .buttonStyle(.plain)
                .disabled(isRunning)

                Divider()
                    .frame(height: 20)

                Button(action: { showIntervalPicker = true }) {
                    if conversationStore.heartbeatConfig.intervalMinutes == nil {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 17))
                    } else {
                        Text(conversationStore.heartbeatConfig.intervalDisplayText)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.plain)
                .padding(7)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color.oceanSecondary)
    }

    func refreshHeartbeat() {
        guard let workingDir = connection.defaultWorkingDirectory else { return }
        connection.syncHistory(sessionId: Heartbeat.sessionId, workingDirectory: workingDir)
    }

    func triggerHeartbeat() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        conversationStore.recordHeartbeatTrigger()
        connection.send(.triggerHeartbeat)
    }
}
