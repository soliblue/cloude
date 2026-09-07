import SwiftUI

struct ChatViewMessageListRowStreamingMarkdown: View {
    let snapshot: ChatLiveSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(StorageKey.typewriterCps) private var cps: Double = TypewriterDefaults.cps
    @AppStorage(StorageKey.typewriterFadeWindow) private var fadeWindow: Double = TypewriterDefaults
        .fadeWindow
    @State private var parsed = ChatMarkdownStreamState()
    @State private var tailLength: Int = 0
    @State private var tailId: String = ""
    @State private var revealedGlyphs: Double = 0
    @State private var ticker: Task<Void, Never>?
    @State private var lastSnapshotId: ObjectIdentifier?
    @State private var lastDeltaCount: Int = 0
    @State private var lastUpdate: Date = .distantPast

    var body: some View {
        let _ = PerfCounters.bump("str.body")
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            if !parsed.frozen.isEmpty {
                ChatViewMessageListRowStreamingMarkdownFrozen(blocks: parsed.frozen)
                    .equatable()
            }
            ForEach(parsed.tail, id: \.id) { block in
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
        .onChange(of: reduceMotion) { _, reduced in
            if reduced {
                ticker?.cancel()
                ticker = nil
                revealedGlyphs = Double(tailLength) + max(1, fadeWindow)
            } else {
                startTicker()
            }
        }
        .onChange(of: snapshot.deltaCount) { _, _ in
            updateIncremental()
            startTicker()
        }
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
        parsed.update(text, appendOnly: appendOnly)
        let newTail = parsed.tail
        let newTailId = newTail.first?.id ?? ""
        if newTailId != tailId {
            revealedGlyphs = 0
            tailId = newTailId
        }
        tailLength = newTail.first.map { Self.charCount(of: $0) } ?? 0
        if isStale || reduceMotion { revealedGlyphs = Double(tailLength) + max(1, fadeWindow) }
    }

    private func startTicker() {
        if !reduceMotion && ticker == nil && revealedGlyphs < Double(tailLength) + max(1, fadeWindow) {
            ticker = Task { @MainActor in
                let frame: Double = 1.0 / 60.0
                while !Task.isCancelled && revealedGlyphs < Double(tailLength) + max(1, fadeWindow) {
                    try? await Task.sleep(for: .milliseconds(16))
                    if !Task.isCancelled {
                        revealedGlyphs = min(
                            Double(tailLength) + max(1, fadeWindow), revealedGlyphs + max(1, cps) * frame)
                    }
                }
                if !Task.isCancelled { ticker = nil }
            }
        }
    }

    private static func charCount(of block: ChatMarkdownBlock) -> Int {
        switch block {
        case .text(_, let attr, _): return attr.characters.count
        case .header(_, _, let attr, _): return attr.characters.count
        case .code(_, let content, _, _): return content.count
        case .blockquote(_, let content): return content.characters.count
        case .table(_, let rows): return rows.reduce(0) { $0 + $1.reduce(0) { $0 + $1.count } }
        case .horizontalRule: return 1
        }
    }
}
