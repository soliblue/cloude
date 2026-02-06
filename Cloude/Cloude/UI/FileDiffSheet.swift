import SwiftUI

struct FileDiffSheet: View {
    let fileName: String
    let diff: String?
    let isLoading: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let diff, !diff.isEmpty {
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        DiffTextView(diff: diff)
                            .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "No Changes",
                        systemImage: "checkmark.circle",
                        description: Text("No unstaged changes for this file")
                    )
                }
            }
            .navigationTitle("Diff: \(fileName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}
