//
//  SettingsView+Components.swift
//  Cloude
//
//  Settings view UI components
//

import SwiftUI

struct SettingsRow<Content: View>: View {
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 24)
            content
        }
    }
}

struct DeviceIPRow: View {
    @Binding var ipCopied: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi")
                .font(.system(size: 20))
                .foregroundColor(.green)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("Device IP")
                    .font(.subheadline)
                Text(NetworkHelper.getIPAddress() ?? "Not available")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: copyIP) {
                Image(systemName: ipCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundColor(ipCopied ? .green : .accentColor)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .disabled(NetworkHelper.getIPAddress() == nil)
        }
    }

    private func copyIP() {
        if let ip = NetworkHelper.getIPAddress() {
            UIPasteboard.general.string = ip
            ipCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                ipCopied = false
            }
        }
    }
}

struct ConnectionStatusCard: View {
    @ObservedObject var connection: ConnectionManager
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let canConnect: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: statusIcon)
                    .font(.system(size: 25))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if connection.isConnected || connection.isAuthenticated {
                Button("Disconnect", action: onDisconnect)
                    .font(.subheadline)
                    .buttonStyle(.bordered)
                    .tint(.red)
            } else {
                Button("Connect", action: onConnect)
                    .font(.subheadline)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canConnect)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.oceanGroupedSecondary)
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var statusColor: Color {
        if connection.isAuthenticated { return .green }
        if connection.isConnected { return .yellow }
        if connection.lastError != nil { return .red }
        return .gray
    }

    private var statusIcon: String {
        if connection.isAuthenticated { return "checkmark.circle.fill" }
        if connection.isConnected { return "ellipsis.circle.fill" }
        if connection.lastError != nil { return "exclamationmark.triangle.fill" }
        return "circle.dashed"
    }

    private var statusTitle: String {
        if connection.isAuthenticated { return "Connected" }
        if connection.isConnected { return "Authenticating..." }
        if connection.lastError != nil { return "Failed" }
        return "Not Connected"
    }

    private var statusSubtitle: String {
        if connection.isAuthenticated { return "Ready to chat with Claude" }
        if connection.isConnected { return "Verifying credentials..." }
        if let error = connection.lastError { return error }
        return "Enter details below"
    }
}
