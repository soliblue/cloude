import SwiftData
import SwiftUI

struct WindowsViewSwitcherAddPill: View {
    @Environment(\.modelContext) private var context
    let windows: [Window]

    var body: some View {
        IconPillButton(symbol: "plus") {
            WindowActions.addNew(into: context, after: windows)
        }
    }
}
