import SwiftUI
import CloudeShared

struct MemoriesSheet: View {
    let sections: [MemorySection]
    @Environment(\.dismiss) private var dismiss
    @State private var expandedSection: String?

    var body: some View {
        NavigationStack {
            List {
                if sections.isEmpty {
                    ContentUnavailableView(
                        "No Memories",
                        systemImage: "brain",
                        description: Text("Claude's memories will appear here once loaded")
                    )
                } else {
                    ForEach(sections) { section in
                        MemorySectionRow(
                            section: section,
                            isExpanded: expandedSection == section.id,
                            onTap: {
                                withAnimation {
                                    if expandedSection == section.id {
                                        expandedSection = nil
                                    } else {
                                        expandedSection = section.id
                                    }
                                }
                            }
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Memories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

struct MemorySectionRow: View {
    let section: MemorySection
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onTap) {
                HStack {
                    Image(systemName: iconForSection(section.title))
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    Text(section.title)
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                StreamingMarkdownView(text: section.content)
                    .font(.subheadline)
                    .padding(.leading, 32)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconForSection(_ title: String) -> String {
        switch title.lowercased() {
        case let t where t.contains("identity"): return "person.fill"
        case let t where t.contains("understanding"): return "lightbulb.fill"
        case let t where t.contains("preference"): return "heart.fill"
        case let t where t.contains("workflow"): return "arrow.triangle.2.circlepath"
        case let t where t.contains("history"): return "clock.fill"
        case let t where t.contains("thread"): return "bubble.left.and.bubble.right.fill"
        case let t where t.contains("rule"): return "list.bullet"
        default: return "doc.text.fill"
        }
    }
}
