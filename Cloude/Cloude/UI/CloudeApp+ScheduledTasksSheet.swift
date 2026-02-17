import SwiftUI
import CloudeShared

struct ScheduledTasksSheet: View {
    @Binding var tasks: [ScheduledTask]
    var isLoading: Bool = false
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    var onOpenConversation: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.secondary.opacity(0.5))
                    Spacer()
                } else if tasks.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.3))
                        Text("No scheduled tasks")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Ask Cloude to schedule something")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(tasks) { task in
                                ScheduledTaskCard(
                                    task: task,
                                    onToggle: { toggleTask(task) },
                                    onDelete: { deleteTask(task) },
                                    onTap: { openTask(task) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Scheduled Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.oceanBackground)
    }

    private func toggleTask(_ task: ScheduledTask) {
        connection.toggleScheduledTask(taskId: task.id, isActive: !task.isActive)
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].isActive.toggle()
        }
    }

    private func deleteTask(_ task: ScheduledTask) {
        connection.deleteScheduledTask(taskId: task.id)
        tasks.removeAll { $0.id == task.id }
    }

    private func openTask(_ task: ScheduledTask) {
        if let convUUID = UUID(uuidString: task.conversationId),
           let conv = conversationStore.findConversation(withId: convUUID) {
            if let wd = conv.workingDirectory ?? connection.defaultWorkingDirectory,
               let sessionId = conv.sessionId {
                connection.syncHistory(sessionId: sessionId, workingDirectory: wd)
            }
            conversationStore.selectConversation(conv)
            onOpenConversation?()
        }
    }
}

struct ScheduledTaskCard: View {
    let task: ScheduledTask
    var onToggle: () -> Void
    var onDelete: () -> Void
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(task.isActive ? .primary : .secondary)
                        .lineLimit(1)

                    Text(task.schedule.displayString)
                        .font(.system(size: 12))
                        .foregroundColor(task.isActive ? .accentColor.opacity(0.8) : .secondary.opacity(0.5))

                    if let nextRun = task.nextRun, task.isActive {
                        Text("Next: \(relativeTime(nextRun))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                    }

                    if let lastRun = task.lastRun {
                        Text("Last: \(relativeTime(lastRun))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { task.isActive },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
                .tint(.accentColor)
            }
            .padding(14)
            .background(.white.opacity(task.isActive ? 0.08 : 0.04))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(task.isActive ? 0.12 : 0.06), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
