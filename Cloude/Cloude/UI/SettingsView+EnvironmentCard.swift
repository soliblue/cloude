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
        VStack(spacing: DS.Spacing.m) {
            headerRow
            formFields
            Spacer().frame(height: DS.Spacing.xs)
        }
        .padding(.horizontal, DS.Spacing.xs)
    }

    private var headerRow: some View {
        HStack(spacing: DS.Spacing.m) {
            Button(action: { showSymbolPicker = true }) {
                Image(systemName: env.symbol)
                    .font(.system(size: DS.Icon.l))
                    .foregroundColor(.accentColor)
                    .frame(width: DS.Size.button, height: DS.Size.button)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showSymbolPicker, onDismiss: { onUpdate(env) }) {
                SymbolPickerSheet(selectedSymbol: $env.symbol)
            }

            HStack(spacing: DS.Spacing.s) {
                Circle()
                    .fill(statusColor)
                    .frame(width: DS.Spacing.s, height: DS.Spacing.s)
                Text(statusText)
                    .font(.system(size: DS.Text.m))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let onDelete {
                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: DS.Icon.s))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .confirmationDialog("Delete \(env.host)?", isPresented: $showDeleteConfirm) {
                    Button("Delete", role: .destructive, action: onDelete)
                }

                Divider().frame(height: DS.Size.divider)
            }

            Button(action: {
                if isConnected { onDisconnect() }
                else if !isConnecting { onConnect() }
            }) {
                Image(systemName: "power")
                    .font(.system(size: DS.Icon.m))
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
                .font(.system(size: DS.Icon.l, weight: .light))
                .foregroundColor(.secondary.opacity(DS.Opacity.half))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}
