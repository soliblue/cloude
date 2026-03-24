import SwiftUI

struct DebugOverlayView: View {
    @ObservedObject var metrics: DebugMetrics
    @State private var expanded = false
    @State private var position = CGPoint(x: 70, y: 100)
    @GestureState private var dragOffset = CGSize.zero

    private var fpsColor: Color {
        if metrics.fps >= 55 { return .pastelGreen }
        if metrics.fps >= 30 { return .yellow }
        return .red
    }

    var body: some View {
        Group {
            if expanded { expandedView } else { minimizedView }
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
                .font(.caption2.weight(.medium).monospaced())
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
                    .font(.footnote.weight(.bold).monospaced())
                Spacer()
                Button(action: { expanded = false }) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                metricRow("FPS", value: "\(metrics.fps)", color: fpsColor)
                metricRow("OWC/sec", value: "\(metrics.objectWillChangeRate)", color: metrics.objectWillChangeRate > 10 ? .red : .pastelGreen)
            }
        }
        .padding(10)
        .frame(width: 160)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func metricRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption2.weight(.semibold).monospaced())
                .foregroundColor(color)
        }
    }
}
