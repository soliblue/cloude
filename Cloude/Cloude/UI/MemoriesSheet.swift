import SwiftUI
import CloudeShared

struct MemoriesSheet: View {
    let sections: [MemorySection]
    var isLoading: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var expandedPaths: Set<String> = []
    @State private var parsedSections: [ParsedMemorySection] = []

    private let maxCharacters = 50_000

    private var totalCharacters: Int {
        sections.reduce(0) { $0 + $1.content.count + $1.title.count + 4 }
    }

    private var usagePercent: Double {
        min(1.0, Double(totalCharacters) / Double(maxCharacters))
    }

    private var usageColor: Color {
        if usagePercent >= 0.95 { return .red }
        if usagePercent >= 0.80 { return .orange }
        return .accentColor
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading memories...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else if parsedSections.isEmpty {
                    ContentUnavailableView(
                        "No Memories",
                        systemImage: "brain",
                        description: Text("Claude's memories will appear here once loaded")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(parsedSections) { section in
                            MemorySectionCard(
                                section: section,
                                depth: 0,
                                expandedPaths: $expandedPaths
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(.ultraThinMaterial)
            .scrollContentBackground(.hidden)
            .navigationTitle("Memories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MemoryUsageIndicator(
                        used: totalCharacters,
                        max: maxCharacters,
                        percent: usagePercent,
                        color: usageColor
                    )
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .presentationBackground(.ultraThinMaterial)
        .onAppear {
            parsedSections = MemoryParser.parse(sections: sections)
        }
        .onChange(of: sections) { _, newSections in
            parsedSections = MemoryParser.parse(sections: newSections)
        }
    }
}

struct MemorySectionCard: View {
    let section: ParsedMemorySection
    let depth: Int
    @Binding var expandedPaths: Set<String>

    private var isExpanded: Bool {
        expandedPaths.contains(section.id)
    }

    private var depthIndent: CGFloat {
        CGFloat(depth) * 12
    }

    private var backgroundColor: Color {
        switch depth {
        case 0: return Color(.secondarySystemGroupedBackground)
        case 1: return Color(.tertiarySystemGroupedBackground)
        default: return Color(.quaternarySystemFill)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedPaths.remove(section.id)
                    } else {
                        expandedPaths.insert(section.id)
                    }
                }
            } label: {
                HStack(spacing: depth == 0 ? 12 : 8) {
                    Image(systemName: "chevron.right")
                        .font(depth == 0 ? .footnote : .caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Text(section.title)
                        .font(depth == 0 ? .headline : .subheadline)
                        .fontWeight(depth == 0 ? .semibold : .medium)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("\(section.childCount)")
                        .font(depth == 0 ? .subheadline : .caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 16 + depthIndent)
                .padding(.trailing, 16)
                .padding(.vertical, depth == 0 ? 14 : 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(section.subsections) { subsection in
                        MemorySectionCard(
                            section: subsection,
                            depth: depth + 1,
                            expandedPaths: $expandedPaths
                        )
                    }

                    ForEach(section.items) { item in
                        MemoryItemCard(item: item, depth: depth)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: depth == 0 ? 12 : 8))
    }
}

struct MemoryUsageIndicator: View {
    let used: Int
    let max: Int
    let percent: Double
    let color: Color

    private var formattedUsed: String {
        if used >= 1000 {
            return String(format: "%.1fK", Double(used) / 1000)
        }
        return "\(used)"
    }

    private var formattedMax: String {
        "\(max / 1000)K"
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("\(formattedUsed) / \(formattedMax)")
                .font(.caption2)
                .foregroundColor(.secondary)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 40, height: 6)

                Capsule()
                    .fill(color)
                    .frame(width: 40 * percent, height: 6)
            }
        }
    }
}

struct MemoryItemCard: View {
    let item: MemoryItem
    var depth: Int = 0

    private var backgroundColor: Color {
        switch depth {
        case 0: return Color(.tertiarySystemGroupedBackground)
        case 1: return Color(.quaternarySystemFill)
        default: return Color(.systemFill)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if item.isBullet {
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .padding(.top, 6)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let date = item.timestamp {
                    Text(formatDate(date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(LocalizedStringKey(item.content))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
