import SwiftUI

struct FilePreviewScrollContainer<Content: View>: View {
    let axes: Axis.Set
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            ScrollView(axes) {
                content()
                    .frame(
                        minWidth: geo.size.width, minHeight: geo.size.height,
                        alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.topLeading)
        }
    }
}
