// SettingsView+EnvironmentCard.swift

import SwiftUI

struct EnvironmentCard: View {
    @State var env: ServerEnvironment
    let isActive: Bool
    let isConnected: Bool
    let isConnecting: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onUpdate: (ServerEnvironment) -> Void
    let onDelete: (() -> Void)?

    @State var showToken = false
    @State private var showDeleteConfirm = false
    @State private var showSymbolPicker = false

    var body: some View {
        VStack(spacing: 12) {
            headerRow
            formFields
            Spacer().frame(height: 2)
        }
        .padding(.horizontal, 4)
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Button(action: { showSymbolPicker = true }) {
                Image(systemName: env.symbol)
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showSymbolPicker, onDismiss: { onUpdate(env) }) {
                SymbolPickerSheet(selectedSymbol: $env.symbol)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let onDelete {
                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .confirmationDialog("Delete \(env.host)?", isPresented: $showDeleteConfirm) {
                    Button("Delete", role: .destructive, action: onDelete)
                }

                Divider().frame(height: 20)
            }

            Button(action: {
                if isConnected { onDisconnect() }
                else if !isConnecting { onConnect() }
            }) {
                Image(systemName: "power")
                    .font(.system(size: 16))
                    .foregroundStyle(isConnected || isConnecting ? Color.accentColor : .secondary)
                    .modifier(StreamingPulseModifier(isStreaming: isConnecting))
            }
            .buttonStyle(.plain)
            .disabled(env.host.isEmpty || env.token.isEmpty)
        }
    }

    private var statusColor: Color {
        if isConnected { return .pastelGreen }
        if isConnecting { return .yellow }
        return .gray
    }

    private var statusText: String {
        if isConnected { return "Connected" }
        if isConnecting { return "Connecting..." }
        return "Not connected"
    }
}

struct AddEnvironmentCard: View {
    let onAdd: (ServerEnvironment) -> Void

    var body: some View {
        Button(action: {
            onAdd(ServerEnvironment(host: "", port: 8765, token: ""))
        }) {
            Image(systemName: "plus")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(.secondary.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}
