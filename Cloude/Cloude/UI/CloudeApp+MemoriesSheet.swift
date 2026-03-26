import SwiftUI
import CloudeShared

struct MemoriesSheet: View {
    let sections: [MemorySection]
    var isLoading: Bool = false
    var fromCache: Bool = false
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

    private var usageColor: Color { .accentColor }


    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if isLoading {
                    VStack(spacing: DS.Spacing.m) {
                        ProgressView()
                        Text("Loading memories...")
                            .font(.system(size: DS.Text.m))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xxl)
                } else if parsedSections.isEmpty {
                    ContentUnavailableView(
                        "No Memories",
                        systemImage: "brain",
                        description: Text("Claude's memories will appear here once loaded")
                    )
                    .padding(.top, DS.Spacing.xxl)
                } else {
                    LazyVStack(spacing: DS.Spacing.m) {
                        ForEach(parsedSections) { section in
                            MemorySectionCard(
                                section: section,
                                depth: 0,
                                expandedPaths: $expandedPaths
                            )
                        }
                    }
                    .padding(.horizontal, DS.Spacing.l)
                    .padding(.vertical, DS.Spacing.m)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: DS.Icon.s, weight: .medium))
                    }
                }
                if fromCache && !isLoading {
                    ToolbarItem(placement: .topBarTrailing) {
                        Label("Cached", systemImage: "arrow.clockwise.icloud")
                            .font(.system(size: DS.Text.s))
                            .foregroundColor(.secondary)
                    }
                }
                if isLoading && !sections.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .toolbarBackground(Color.themeSecondary, for: .navigationBar)
        }
        .presentationBackground {
            ZStack {
                Rectangle().fill(Color.themeBackground)
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: geo.size.height * usagePercent)
                    }
                }
            }
        }
        .onAppear {
            parsedSections = MemoryParser.parse(sections: sections)
        }
        .onChange(of: sections) { _, newSections in
            parsedSections = MemoryParser.parse(sections: newSections)
        }
    }
}
