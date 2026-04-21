import SwiftUI

struct SettingsPill: View {
    @Binding var isPresented: Bool

    var body: some View {
        IconPillButton(symbol: "gearshape.fill") { isPresented = true }
    }
}
