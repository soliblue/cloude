import SwiftUI

struct DebugOverlayView: View {
    @StateObject private var metrics = DebugMetrics.shared
    @State private var expanded = false
    @State private var showLogs = false
    @State private var displayedLogs: [DebugEntry] = []
    @State private var selectedSource: String? = nil
    @State private var availableSources: [String] = []
    @State private var position = CGPoint(x: 70, y: 100)
    @GestureState private var dragOffset = CGSize.zero

    private var fpsColor: Color {
        if metrics.fps >= 55 { return .pastelGreen }
        if metrics.fps >= 30 { return .yellow }
        return .red
    }

    var body: some View {
        Group {
            if showLogs { logView } else if expanded { expandedView } else { minimizedView }
        }
        .position(x: position.x + dragOffset.width, y: position.y + dragOffset.height)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in state = value.translation }
                .onEnded { value in
                    position.x += value.translation.width
                    position.y += value.translation.height
                }
        )
    }

    private var minimizedView: some View {
        HStack(spacing: DS.Spacing.s) {
            Circle()
                .fill(fpsColor)
                .frame(width: DS.Text.s, height: DS.Text.s)
            Text("\(metrics.fps)fps")
                .font(.system(size: DS.Text.s, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, DS.Spacing.s)
        .padding(.vertical, DS.Spacing.xs)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .onTapGesture { expanded = true }
    }

    private var totalLogCount: Int {
        metrics.logBuffers.values.reduce(0) { $0 + $1.count }
    }

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack {
                Text("Debug")
                    .font(.system(size: DS.Text.m, weight: .bold, design: .monospaced))
                Spacer()
                Button(action: { expanded = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.Text.s, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                metricRow("FPS", value: "\(metrics.fps)", color: fpsColor)
                metricRow("OWC/sec", value: "\(metrics.objectWillChangeRate)", color: metrics.objectWillChangeRate > 10 ? .red : .pastelGreen)
                metricRow("Logs", value: "\(totalLogCount)", color: .secondary)
            }

            Button(action: {
                refreshLogs()
                showLogs = true
            }) {
                Text("View Logs")
                    .font(.system(size: DS.Text.s, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(DS.Spacing.m)
        .frame(width: DS.Size.xxl * 0.8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
    }

    private func refreshLogs() {
        availableSources = metrics.sources
        displayedLogs = metrics.logs(for: selectedSource)
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.s) {
                Text("Logs (\(displayedLogs.count))")
                    .font(.system(size: DS.Text.m, weight: .bold, design: .monospaced))
                Spacer()
                Button(action: refreshLogs) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: DS.Text.s, weight: .bold))
                        .foregroundColor(.accentColor)
                }
                Button(action: {
                    let text = displayedLogs.map { "\(Self.timeFormatter.string(from: $0.time)) [\($0.source)] \($0.message)" }.joined(separator: "\n")
                    UIPasteboard.general.string = text
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: DS.Text.s, weight: .bold))
                        .foregroundColor(.accentColor)
                }
                Button(action: {
                    metrics.clearLogs()
                    displayedLogs = []
                    availableSources = []
                    selectedSource = nil
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: DS.Text.s, weight: .bold))
                        .foregroundColor(.secondary)
                }
                Button(action: { showLogs = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.Text.s, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    filterChip("All", isSelected: selectedSource == nil) {
                        selectedSource = nil
                        refreshLogs()
                    }
                    ForEach(availableSources, id: \.self) { source in
                        filterChip(source, isSelected: selectedSource == source) {
                            selectedSource = source
                            refreshLogs()
                        }
                    }
                }
            }

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        ForEach(displayedLogs) { entry in
                            logEntryRow(entry)
                                .id(entry.id)
                        }
                    }
                }
                .onChange(of: displayedLogs.count) { _, _ in
                    if let last = displayedLogs.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .padding(DS.Spacing.m)
        .frame(width: DS.Size.xxl * 1.6, height: DS.Size.xxl * 2)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
    }

    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: DS.Text.s, weight: isSelected ? .bold : .medium, design: .monospaced))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, DS.Spacing.s)
                .padding(.vertical, DS.Spacing.xs)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(DS.Opacity.light))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "mm:ss.SSS"
        return f
    }()

    private func logEntryRow(_ entry: DebugEntry) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.s) {
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.source)
                    .foregroundColor(.accentColor)
                Text(Self.timeFormatter.string(from: entry.time))
                    .foregroundColor(.secondary)
            }
            .frame(width: DS.Size.xl, alignment: .leading)

            Text(entry.message)
                .foregroundColor(.primary)
                .lineLimit(3)
        }
        .font(.system(size: DS.Text.s, design: .monospaced))
    }

    private func metricRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: DS.Text.s, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: DS.Text.s, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}
