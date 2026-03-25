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

struct TeamSummaryBadge: View {
    let summary: TeamSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                HStack(spacing: -4) {
                    ForEach(summary.members) { member in
                        Circle()
                            .fill(teammateColor(member.color).opacity(0.6))
                            .frame(width: 14, height: 14)
                            .overlay {
                                Text(String(member.name.prefix(1)).uppercased())
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                    }
                }
                Text(summary.teamName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
    @Binding var showTeamDashboard: Bool
    let onToggleCollapse: (() -> Void)?

    func body(content: Content) -> some View {
        if isLive {
            content
        } else {
            content
                .sheet(isPresented: $showTextSelection) {
                    TextSelectionSheet(text: effectiveText)
                }
                .sheet(isPresented: $showTeamDashboard) {
                    if let team = message.teamSummary {
                        TeamDashboardSheet(
                            teamName: team.teamName,
                            teammates: team.members.map {
                                TeammateInfo(id: $0.name, name: $0.name, agentType: $0.agentType, model: $0.model, color: $0.color, status: .shutdown)
                            }
                        )
                    }
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
                }
        }
    }
}
