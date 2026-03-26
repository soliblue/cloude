// MessageBubble+ActionMenu.swift

import SwiftUI
import UIKit
import CloudeShared

struct ConditionalClip: ViewModifier {
    let isClipped: Bool
    func body(content: Content) -> some View {
        if isClipped {
            content.clipped()
        } else {
            content
        }
    }
}

struct CopyFeedback {
    static func perform(_ text: String, showToast: Binding<Bool>) {
        ClipboardHelper.copy(text)
        withAnimation { showToast.wrappedValue = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showToast.wrappedValue = false }
        }
    }
}

struct BubbleInteractionModifier: ViewModifier {
    let isLive: Bool
    let message: ChatMessage
    let effectiveText: String
    let hasInteractiveWidgets: Bool
    @Binding var showCopiedToast: Bool
    @Binding var showTextSelection: Bool
    let onToggleCollapse: (() -> Void)?
    var onRefresh: (() -> Void)?
    var isRefreshing: Bool = false
    @State private var showInfo = false

    func body(content: Content) -> some View {
        if isLive {
            content
        } else {
            content
                .sheet(isPresented: $showTextSelection) {
                    TextSelectionSheet(text: effectiveText)
                }
                .sheet(isPresented: $showInfo) {
                    MessageInfoSheet(message: message)
                }
                .contextMenu {
                    Button {
                        CopyFeedback.perform(effectiveText, showToast: $showCopiedToast)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }

                    if !message.text.isEmpty {
                        Button {
                            showTextSelection = true
                        } label: {
                            Label("Select Text", systemImage: "text.cursor")
                        }
                    }

                    if !message.isUser && !message.text.isEmpty {
                        Button {
                            onToggleCollapse?()
                        } label: {
                            Label(message.isCollapsed ? "Expand" : "Collapse", systemImage: message.isCollapsed ? "chevron.down" : "chevron.up")
                        }
                    }

                    if let onRefresh, !message.isUser {
                        Button {
                            onRefresh()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(isRefreshing)
                    }

                    Button {
                        showInfo = true
                    } label: {
                        Label("Info", systemImage: "info.circle")
                    }
                }
        }
    }
}

struct MessageInfoSheet: View {
    let message: ChatMessage
    @Environment(\.dismiss) private var dismiss

    private var rows: [(String, String)] {
        var result: [(String, String)] = [
            ("clock", DateFormatters.messageTimestamp(message.timestamp))
        ]
        if let model = message.model {
            let identity = ModelIdentity(model)
            result.append((identity.icon, identity.displayName))
        }
        if let durationMs = message.durationMs {
            result.append(("timer", formattedDuration(durationMs)))
        }
        if let costUsd = message.costUsd {
            result.append(("dollarsign.circle", formattedCost(costUsd)))
        }
        result.append(("textformat.size", "\(message.text.count) chars"))
        if !message.toolCalls.isEmpty {
            result.append(("wrench", "\(message.toolCalls.count) tool calls"))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 {
                        Divider()
                    }
                    infoRow(row.0, row.1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.Spacing.l)
                        .padding(.vertical, DS.Spacing.m)
                }
                Spacer()
            }
            .background(Color.themeBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: DS.Icon.s, weight: .medium))
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.themeBackground)
    }

    private func infoRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: DS.Text.s))
                .foregroundColor(.secondary)
                .frame(width: DS.Size.divider)
            Text(text)
                .font(.system(size: DS.Text.m))
        }
    }

    private func formattedDuration(_ ms: Int) -> String {
        let seconds = Double(ms) / 1000.0
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        }
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return "\(minutes)m \(remainingSeconds)s"
    }

    private func formattedCost(_ usd: Double) -> String {
        usd < 0.01 ? String(format: "$%.4f", usd) : String(format: "$%.2f", usd)
    }
}
