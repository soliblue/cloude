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

    func body(content: Content) -> some View {
        if isLive {
            content
        } else {
            content
                .sheet(isPresented: $showTextSelection) {
                    TextSelectionSheet(text: effectiveText)
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
