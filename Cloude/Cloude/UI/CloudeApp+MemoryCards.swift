import SwiftUI
import CloudeShared

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
        Color.themeSecondary.opacity(depth == 0 ? 1.0 : 0.7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.quickTransition) {
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

                    if let icon = section.icon {
                        Image(systemName: icon)
                            .font(depth == 0 ? .body : .subheadline)
                            .foregroundColor(.accentColor)
                    }

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
        .clipShape(RoundedRectangle(cornerRadius: depth == 0 ? 9 : 6))
    }
}


struct MemoryItemCard: View {
    let item: MemoryItem
    var depth: Int = 0

    private var backgroundColor: Color {
        Color.themeSecondary.opacity(depth == 0 ? 0.8 : 0.6)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                if let date = item.timestamp {
                    Text(formatDate(date))
                        .font(.system(size: DS.Text.s))
                        .foregroundColor(.secondary)
                }

                Text(LocalizedStringKey(item.content))
                    .font(.system(size: DS.Text.m))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func formatDate(_ date: Date) -> String {
        DateFormatters.mediumDate(date)
    }
}
