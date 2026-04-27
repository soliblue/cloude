import SwiftUI

struct ChatViewMessageListRowStreamingMarkdown: View {
    let text: String
    @State private var frozen: [ChatMarkdownBlock] = []
    @State private var tailBlocks: [ChatMarkdownBlock] = []
    @State private var tailLength: Int = 0
    @State private var tailId: String = ""
    @State private var revealedGlyphs: Double = 0
    @State private var ticker: Task<Void, Never>?
    @State private var lastText: String = ""

    var body: some View {
        let _ = PerfCounters.bump("str.body")
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            if !frozen.isEmpty {
                ChatViewMessageListRowStreamingMarkdownFrozen(blocks: frozen)
                    .equatable()
            }
            ForEach(tailBlocks, id: \.id) { block in
                ChatViewMessageListRowMarkdownBlock(block: block)
            }
            .textRenderer(ChatTypewriterTextRenderer(revealedGlyphs: revealedGlyphs))
        }
        .appFont(size: ThemeTokens.Text.m)
        .onAppear {
            updateIncremental()
            startTicker()
        }
        .onDisappear {
            ticker?.cancel()
            ticker = nil
        }
        .onChange(of: text) { _, _ in updateIncremental() }
    }

    private func updateIncremental() {
        if text == lastText { return }
        lastText = text
        let blocks = ChatMarkdownParser.parse(text)
        let newTail = Array(blocks.suffix(1))
        let newTailId = newTail.first?.id ?? ""
        if newTailId != tailId {
            revealedGlyphs = 0
            tailId = newTailId
        }
        frozen = Array(blocks.dropLast())
        tailBlocks = newTail
        tailLength = newTail.first.map(Self.charCount(of:)) ?? 0
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { @MainActor in
            let frame: Double = 1.0 / 60.0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                let total = Double(tailLength)
                if revealedGlyphs >= total { continue }
                let cps = 50.0
                revealedGlyphs = min(total, revealedGlyphs + cps * frame)
            }
        }
    }

    private static func charCount(of block: ChatMarkdownBlock) -> Int {
        switch block {
        case .text(_, let attr, _): return attr.characters.count
        case .header(_, _, let attr, _): return attr.characters.count
        case .code(_, let content, _, _): return content.count
        case .blockquote(_, let content): return content.count
        case .table(_, let rows): return rows.reduce(0) { $0 + $1.reduce(0) { $0 + $1.count } }
        case .horizontalRule: return 1
        }
    }
}
