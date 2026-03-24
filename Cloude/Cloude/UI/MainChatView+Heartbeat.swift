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
                    .font(.footnote)
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
                        .font(.footnote)
                    Text(heartbeat.name)
                } else {
                    Text("Heartbeat")
                }
            }
            .font(.caption2)
            .fontWeight(.medium)

            Spacer()

            HStack(spacing: 0) {
                Button(action: refreshHeartbeat) {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(isRunning ? .secondary.opacity(0.3) : .secondary)
                        .padding(7)
                }
                .buttonStyle(.plain)
                .disabled(isRunning)

                Divider()
                    .frame(height: 20)

                heartbeatEnvironmentMenu

                Divider()
                    .frame(height: 20)

                Button(action: { showIntervalPicker = true }) {
                    if conversationStore.heartbeatConfig.intervalMinutes == nil {
                        Image(systemName: "clock.badge.xmark")
                            .font(.subheadline)
                    } else {
                        Text(conversationStore.heartbeatConfig.intervalDisplayText)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.plain)
                .padding(7)
            }
        }
        .padding(.horizontal, 11)
        .padding(.top, 0)
        .padding(.bottom, 7)
        .background(Color.themeSecondary)
    }

    private var heartbeatEnvironmentMenu: some View {
        let effectiveEnvId = heartbeatEnvironmentId ?? environmentStore.activeEnvironmentId
        let currentEnv = environmentStore.environments.first { $0.id == effectiveEnvId }

        return Menu {
            ForEach(environmentStore.environments) { env in
                Button(action: { heartbeatEnvironmentId = env.id }) {
                    Label {
                        Text(env.host.isEmpty ? "No host" : env.host)
                    } icon: {
                        Image(systemName: env.id == effectiveEnvId ? "checkmark" : env.symbol)
                    }
                }
            }
        } label: {
            Image(systemName: currentEnv?.symbol ?? "laptopcomputer")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(7)
        }
    }

    var heartbeatEnvId: UUID? {
        heartbeatEnvironmentId ?? environmentStore.activeEnvironmentId
    }

    func refreshHeartbeat() {
        let conn = heartbeatEnvId.flatMap { connection.connection(for: $0) } ?? activeEnvConnection
        guard let workingDir = conn?.defaultWorkingDirectory else { return }
        connection.syncHistory(sessionId: Heartbeat.sessionId, workingDirectory: workingDir, environmentId: heartbeatEnvId)
    }

    func triggerHeartbeat() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        conversationStore.recordHeartbeatTrigger()
        connection.send(.triggerHeartbeat, environmentId: heartbeatEnvId)
    }
}
