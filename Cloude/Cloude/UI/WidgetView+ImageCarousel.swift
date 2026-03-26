import SwiftUI
import Combine

struct ImageCarouselWidget: View {
    let data: [String: Any]
    @EnvironmentObject var connection: ConnectionManager

    @State private var selectedIndex = 0
    @State private var previewPath: String?

    private var title: String? { data["title"] as? String }
    private var images: [(path: String?, url: String?, caption: String?)] {
        guard let arr = data["images"] as? [[String: Any]] else { return [] }
        return arr.map { (path: $0["path"] as? String, url: $0["url"] as? String, caption: $0["caption"] as? String) }
    }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "photo.on.rectangle", title: title, color: .green)

            if images.count == 1, let image = images.first {
                imageSlide(image)
            } else if images.count > 1 {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        imageSlide(image)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: DS.Size.chart)
            }
        }
        .sheet(item: $previewPath) { path in
            FilePreviewView(path: path, connection: connection)
        }
    }

    @ViewBuilder
    private func imageSlide(_ image: (path: String?, url: String?, caption: String?)) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Group {
                if let path = image.path {
                    FileImageView(path: path)
                        .environmentObject(connection)
                } else if let urlStr = image.url, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fit)
                        case .failure:
                            placeholderView(icon: "exclamationmark.triangle")
                        default:
                            ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
            .onTapGesture {
                if let path = image.path {
                    previewPath = path
                } else if let urlStr = image.url, let url = URL(string: urlStr) {
                    UIApplication.shared.open(url)
                }
            }

            if let caption = image.caption {
                Text(caption)
                    .font(.system(size: DS.Text.s))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func placeholderView(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: DS.Icon.l))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(Color.themeSecondary.opacity(DS.Opacity.strong))
    }
}

struct FileImageView: View {
    let path: String
    @EnvironmentObject var connection: ConnectionManager
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var cancellable: AnyCancellable?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: DS.Icon.l))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(Color.themeSecondary.opacity(DS.Opacity.strong))
            }
        }
        .onAppear {
            if let cached = connection.fileCache.get(path), let img = UIImage(data: cached) {
                image = img
                isLoading = false
                return
            }

            connection.getFile(path: path)
            cancellable = connection.events
                .receive(on: DispatchQueue.main)
                .sink { event in
                    switch event {
                    case .fileContent(let p, let data, _, _, _):
                        if p == path, let decoded = Data(base64Encoded: data), let img = UIImage(data: decoded) {
                            image = img
                            isLoading = false
                        }
                    case .fileThumbnail(let p, let data, _):
                        if p == path, let decoded = Data(base64Encoded: data), let img = UIImage(data: decoded) {
                            image = img
                            isLoading = false
                        }
                    case .fileError:
                        isLoading = false
                    default:
                        break
                    }
                }
        }
    }
}
