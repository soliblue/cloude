import SwiftUI

struct WindowCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: DS.Icon.m, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}
