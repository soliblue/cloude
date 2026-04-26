import HighlightSwift
import SwiftUI

struct ChatViewMessageListRowToolPillSheetBash: View {
    let toolCall: ChatToolCall

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
            if let description = toolCall.parsedInput["description"] as? String,
                !description.isEmpty
            {
                Text(description)
                    .appFont(size: ThemeTokens.Text.l, weight: .semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !chips.isEmpty {
                HStack(spacing: ThemeTokens.Spacing.s) {
                    ForEach(chips) { chip in
                        ChatViewMessageListRowToolPillSheetChip(
                            icon: chip.icon, label: chip.label, tint: ChatToolKind.bash.color)
                    }
                }
            }
            if let command = toolCall.parsedInput["command"] as? String, !command.isEmpty {
                ChatViewMessageListRowToolPillSheetSection(title: "Command", icon: "terminal") {
                    CodeText(command)
                        .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var chips: [ChatToolChip] {
        var result: [ChatToolChip] = []
        if toolCall.parsedInput["run_in_background"] as? Bool == true {
            result.append(ChatToolChip(icon: "clock.arrow.circlepath", label: "background"))
        }
        if let timeout = toolCall.parsedInput["timeout"] as? Int {
            let seconds = timeout / 1000
            result.append(
                ChatToolChip(icon: "timer", label: seconds >= 60 ? "\(seconds / 60)m" : "\(seconds)s"))
        }
        return result
    }
}
