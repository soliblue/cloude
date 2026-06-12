import SwiftUI

struct ChatViewMessageListRowStreamingMarkdown: View {
    let snapshot: ChatLiveSnapshot
    @AppStorage(StorageKey.typewriterCps) private var cps: Double = TypewriterDefaults.cps
    @AppStorage(StorageKey.typewriterFadeWindow) private var fadeWindow: Double = TypewriterDefaults
        .fadeWindow
    @State private var frozen: [ChatMarkdownBlock] = []
    @State private var tailBlocks: [ChatMarkdownBlock] = []
    @State private var tailLength: Int = 0
    @State private var tailId: String = ""
    @State private var revealedGlyphs: Double = 0
    @State private var ticker: Task<Void, Never>?
    @State private var lastSnapshotId: ObjectIdentifier?
    @State private var lastDeltaCount: Int = 0
    @State private var lastUpdate: Date = .distantPast
    @State private var tailStartLine: Int = 0
    @State private var tailStartUTF8: Int = 0

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
            .textRenderer(
                ChatTypewriterTextRenderer(
                    revealedGlyphs: revealedGlyphs, fadeWindow: fadeWindow))
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
        .onChange(of: snapshot.deltaCount) { _, _ in updateIncremental() }
    }

    private func updateIncremental() {
        let snapshotId = ObjectIdentifier(snapshot)
        if snapshotId == lastSnapshotId && snapshot.deltaCount == lastDeltaCount { return }
        let text = snapshot.text
        let isStale = Date().timeIntervalSince(lastUpdate) > 0.5
        let appendOnly = snapshotId == lastSnapshotId && snapshot.deltaCount > lastDeltaCount
        lastSnapshotId = snapshotId
        lastDeltaCount = snapshot.deltaCount
        lastUpdate = Date()
        let blocks: [ChatMarkdownBlock]
        if appendOnly,
            let resumed = ChatMarkdownParser.parseResuming(
                text, tailStartLine: tailStartLine, tailStartUTF8: tailStartUTF8)
        {
            blocks = frozen + resumed.blocks
            tailStartLine = resumed.tailStartLine
            tailStartUTF8 = resumed.tailStartUTF8
        } else {
            let full = ChatMarkdownParser.parseWithTailStart(text)
            blocks = full.blocks
            tailStartLine = full.tailStartLine
            tailStartUTF8 = full.tailStartUTF8
        }
        let newTail = Array(blocks.suffix(1))
        let newTailId = newTail.first?.id ?? ""
        if newTailId != tailId {
            revealedGlyphs = 0
            tailId = newTailId
        }
        frozen = Array(blocks.dropLast())
        tailBlocks = newTail
        tailLength = newTail.first.map(Self.charCount(of:)) ?? 0
        if isStale { revealedGlyphs = Double(tailLength) }
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { @MainActor in
            let frame: Double = 1.0 / 60.0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                let total = Double(tailLength)
                if revealedGlyphs >= total { continue }
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
