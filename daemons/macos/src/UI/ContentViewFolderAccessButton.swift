import SwiftUI

struct ContentViewFolderAccessButton: View {
    @AppStorage(FolderAccessProbeService.grantedKey) private var isGranted = false

    @State private var isRequesting = false

    var body: some View {
        if isGranted {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .frame(width: 16, height: 16)
                Text("Folder Access Granted")
                Spacer()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
        } else {
            Button {
                isRequesting = true
                FolderAccessProbeService.shared.request {
                    isRequesting = false
                    isGranted = $0
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isRequesting ? "hourglass" : "folder.badge.plus")
                        .frame(width: 16, height: 16)
                    Text(isRequesting ? "Requesting Folder Access" : "Request Folder Access")
                    Spacer()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isRequesting)
        }
    }
}
