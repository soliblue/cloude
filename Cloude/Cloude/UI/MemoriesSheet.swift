import SwiftUI
import CloudeShared

struct MemoriesSheet: View {
    let sections: [MemorySection]
    var isLoading: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var expandedSections: Set<String> = []

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
                } else if sections.isEmpty {
                    ContentUnavailableView(
                        "No Memories",
                        systemImage: "brain",
                        description: Text("Claude's memories will appear here once loaded")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                            MemorySectionRow(
                                section: section,
                                isExpanded: expandedSections.contains(section.id),
                                onTap: {
                                    if expandedSections.contains(section.id) {
                                        expandedSections.remove(section.id)
                                    } else {
                                        expandedSections.insert(section.id)
                                    }
                                }
                            )
                            if index < sections.count - 1 {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
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
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .presentationBackground(.ultraThinMaterial)
    }
}

struct MemorySectionRow: View {
    let section: MemorySection
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Text(section.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                StreamingMarkdownView(text: section.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
        }
    }
}
