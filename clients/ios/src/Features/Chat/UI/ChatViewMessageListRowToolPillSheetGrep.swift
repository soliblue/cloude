import SwiftUI

struct ChatViewMessageListRowToolPillSheetGrep: View {
    let toolCall: ChatToolCall

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
            if let pattern = toolCall.parsedInput["pattern"] as? String, !pattern.isEmpty {
                ChatViewMessageListRowToolPillSheetSection(
                    title: "Pattern", icon: "text.magnifyingglass"
                ) {
                    Text(pattern)
                        .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            if !chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ThemeTokens.Spacing.s) {
                        ForEach(chips) { chip in
                            ChatViewMessageListRowToolPillSheetChip(
                                icon: chip.icon, label: chip.label, tint: ChatToolKind.grep.color)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private var chips: [ChatToolChip] {
        var result: [ChatToolChip] = []
        if let path = toolCall.parsedInput["path"] as? String, !path.isEmpty {
            result.append(ChatToolChip(icon: "folder", label: (path as NSString).lastPathComponent))
        }
        if let glob = toolCall.parsedInput["glob"] as? String, !glob.isEmpty {
            result.append(ChatToolChip(icon: "doc.text.magnifyingglass", label: glob))
        }
        if let type = toolCall.parsedInput["type"] as? String, !type.isEmpty {
            result.append(ChatToolChip(icon: "doc", label: type))
        }
        if let mode = toolCall.parsedInput["output_mode"] as? String, !mode.isEmpty {
            result.append(ChatToolChip(icon: "rectangle.split.3x1", label: mode))
        }
        for key in ["-A", "-B", "-C", "context"] {
            if let value = toolCall.parsedInput[key] as? Int {
                result.append(ChatToolChip(icon: "plus.forwardslash.minus", label: "\(key) \(value)"))
            }
        }
        if toolCall.parsedInput["multiline"] as? Bool == true {
            result.append(ChatToolChip(icon: "text.justify", label: "multiline"))
        }
        if toolCall.parsedInput["-i"] as? Bool == true {
            result.append(ChatToolChip(icon: "textformat", label: "case-insensitive"))
        }
        if let head = toolCall.parsedInput["head_limit"] as? Int {
            result.append(ChatToolChip(icon: "arrow.up.to.line", label: "head \(head)"))
        }
        return result
    }
}
