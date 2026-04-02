import SwiftUI

struct SettingsButton: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: DS.Icon.m))
            .foregroundColor(.secondary)
            .frame(width: DS.Size.m, height: DS.Size.m)
    }
}
