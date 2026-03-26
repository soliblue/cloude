import SwiftUI

struct DebugOverlayView: View {
    @StateObject private var metrics = DebugMetrics.shared
    @State private var expanded = false
    @State private var showLogs = false
    @State private var displayedLogs: [DebugEntry] = []
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
        HStack(spacing: 6) {
            Circle()
                .fill(fpsColor)
                .frame(width: 6, height: 6)
            Text("\(metrics.fps)fps")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .onTapGesture { expanded = true }
    }

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Debug")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                Spacer()
                Button(action: { expanded = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                metricRow("FPS", value: "\(metrics.fps)", color: fpsColor)
                metricRow("OWC/sec", value: "\(metrics.objectWillChangeRate)", color: metrics.objectWillChangeRate > 10 ? .red : .pastelGreen)
                metricRow("Logs", value: "\(metrics.logBuffer.count)", color: .secondary)
            }

            Button(action: {
                displayedLogs = metrics.logBuffer
                showLogs = true
            }) {
                Text("View Logs")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(10)
        .frame(width: 160)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Logs (\(displayedLogs.count))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                Spacer()
                Button(action: {
                    displayedLogs = metrics.logBuffer
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentColor)
                }
                Button(action: {
                    let text = displayedLogs.map { "\(Self.timeFormatter.string(from: $0.time)) [\($0.source)] \($0.message)" }.joined(separator: "\n")
                    UIPasteboard.general.string = text
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentColor)
                }
                Button(action: {
                    metrics.clearLogs()
                    displayedLogs = []
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                Button(action: { showLogs = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 3) {
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
        .padding(10)
        .frame(width: 320, height: 400)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private func logEntryRow(_ entry: DebugEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.source)
                    .foregroundColor(.accentColor)
                Text(Self.timeFormatter.string(from: entry.time))
                    .foregroundColor(.secondary)
            }
            .frame(width: 52, alignment: .leading)

            Text(entry.message)
                .foregroundColor(.primary)
                .lineLimit(3)
        }
        .font(.system(size: 8, design: .monospaced))
    }

    private func metricRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}
