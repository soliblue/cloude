//
//  SplitChatView+Header.swift
//  Cloude

import SwiftUI

extension SplitChatView {
    func windowHeader(for window: ChatWindow, project: Project?, conversation: Conversation?, showCloseButton: Bool = true) -> some View {
        let gitBranch = project.flatMap { gitBranches[$0.id] }
        let availableTypes = WindowType.allCases.filter { type in
            if type == .gitChanges { return gitBranch != nil }
            return true
        }

        return HStack(spacing: 8) {
            ForEach(availableTypes, id: \.self) { type in
                Button(action: {
                    windowManager.setActive(window.id)
                    windowManager.setWindowType(window.id, type: type)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.system(size: 14))
                        if type == .gitChanges, let branch = gitBranch {
                            Text(branch)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(window.type == type ? .accentColor : .secondary)
                    .padding(6)
                    .background(window.type == type ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button(action: {
                windowManager.setActive(window.id)
                editingWindow = window
            }) {
                HStack(spacing: 4) {
                    if let symbol = conversation?.symbol, !symbol.isEmpty {
                        Image(systemName: symbol)
                            .font(.system(size: 12))
                    }
                    if let conv = conversation {
                        Text(conv.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    } else {
                        Text("Select chat...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let proj = project {
                        Text("• \(proj.name)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showCloseButton {
                Button(action: {
                    windowManager.setActive(window.id)
                    if windowManager.windows.count == 1 {
                        addWindowWithNewChat()
                    } else {
                        windowManager.removeWindow(window.id)
                    }
                }) {
                    Image(systemName: windowManager.windows.count == 1 ? "plus" : "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .disabled(windowManager.windows.count == 1 && !windowManager.canAddWindow)
            } else {
                Button(action: addWindowWithNewChat) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }
}
