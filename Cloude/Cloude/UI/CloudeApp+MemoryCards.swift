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
        CGFloat(depth) * DS.Spacing.m
    }

    private var backgroundColor: Color {
        Color.themeSecondary.opacity(depth == 0 ? 1.0 : DS.Opacity.heavy)
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
                HStack(spacing: depth == 0 ? DS.Spacing.m : DS.Spacing.s) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: depth == 0 ? DS.Text.s : DS.Text.s))
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    if let icon = section.icon {
                        Image(systemName: icon)
                            .font(.system(size: depth == 0 ? DS.Text.m : DS.Text.s))
                            .foregroundColor(.accentColor)
                    }

                    Text(section.title)
                        .font(.system(size: depth == 0 ? DS.Text.m : DS.Text.s))
                        .fontWeight(depth == 0 ? .semibold : .medium)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("\(section.childCount)")
                        .font(.system(size: depth == 0 ? DS.Text.m : DS.Text.s))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, DS.Spacing.l + depthIndent)
                .padding(.trailing, DS.Spacing.l)
                .padding(.vertical, depth == 0 ? DS.Size.s : DS.Size.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
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
                .padding(.horizontal, DS.Spacing.m)
                .padding(.bottom, DS.Spacing.m)
            }
        }
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: depth == 0 ? DS.Radius.m : DS.Radius.s))
    }
}


struct MemoryItemCard: View {
    let item: MemoryItem
    var depth: Int = 0

    private var backgroundColor: Color {
        Color.themeSecondary.opacity(depth == 0 ? DS.Opacity.full : DS.Opacity.heavy)
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
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
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.m)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
    }

    private func formatDate(_ date: Date) -> String {
        DateFormatters.mediumDate(date)
    }
}
