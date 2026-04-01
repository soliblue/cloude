import SwiftUI
import CloudeShared

extension SettingsView {
    private var rootProcesses: [AgentProcessInfo] {
        let allPids = Set(connection.processes.map(\.pid))
        return connection.processes.filter { proc in
            proc.parentPid == nil || !allPids.contains(proc.parentPid!)
        }
    }

    private func children(of parent: AgentProcessInfo) -> [AgentProcessInfo] {
        connection.processes.filter { $0.parentPid == parent.pid }
    }

    var processesSection: some View {
        Section {
            if connection.processes.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: DS.Icon.m))
                        .foregroundColor(.pastelGreen)
                    Text("No Claude processes running")
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(rootProcesses) { proc in
                    processRow(proc, isChild: false)
                    ForEach(children(of: proc)) { child in
                        processRow(child, isChild: true)
                    }
                }

            }
        } header: {
            HStack {
                Text("Claude Processes")
                    .font(.system(size: DS.Text.m))
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: DS.Duration.l)) { refreshRotation += 360 }
                    connection.getProcesses()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: DS.Text.m))
                        .rotationEffect(.degrees(refreshRotation))
                }
                .buttonStyle(.plain)
            }
        } footer: {
            Text("Running Claude Code processes on the Mac agent")
                .font(.system(size: DS.Text.s))
        }
        .listRowBackground(Color.themeSecondary)
    }


    @ViewBuilder
    private func processRow(_ proc: AgentProcessInfo, isChild: Bool) -> some View {
        HStack {
            if isChild {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: DS.Text.s))
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                if let name = proc.conversationName {
                    Text(name)
                        .font(.system(size: isChild ? DS.Text.s : DS.Text.m, weight: .medium))
                        .foregroundColor(isChild ? .secondary : .primary)
                } else {
                    Text("PID \(proc.pid)")
                        .font(.system(size: isChild ? DS.Text.s : DS.Text.m, design: .monospaced))
                        .foregroundColor(isChild ? .secondary : .primary)
                }
                HStack(spacing: DS.Spacing.s) {
                    if proc.conversationName != nil {
                        Text("PID \(proc.pid)")
                            .font(.system(size: DS.Text.s))
                            .foregroundColor(.secondary)
                    }
                    if let start = proc.startTime {
                        Text(start, style: .relative)
                            .font(.system(size: DS.Text.s))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Button(action: { connection.killProcess(pid: proc.pid) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: DS.Icon.m))
            }
            .buttonStyle(.plain)
            .tint(.accentColor)
        }
    }

    var aboutSection: some View {
        Section {
            SettingsRow(icon: "cloud.fill", color: .blue) {
                Text("Cloude")
                    .font(.system(size: DS.Text.m))
                Spacer()
                Text("v1.0")
                    .font(.system(size: DS.Text.s))
                    .foregroundColor(.secondary)
            }

            Link(destination: URL(string: "https://x.com/_xsoli")!) {
                SettingsRow(icon: "questionmark.circle", color: .cyan) {
                    Text("Help & Support")
                        .font(.system(size: DS.Text.m))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
        .listRowBackground(Color.themeSecondary)
    }
}
