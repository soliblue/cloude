import SwiftUI

struct SessionEmptyViewProviderRow: View {
    let session: Session

    var body: some View {
        SessionEmptyViewPickerRow(
            icon: session.provider.symbol,
            title: "Agent",
            value: session.provider.displayName,
            options: ChatProvider.allCases.map { provider in
                SessionEmptyViewPickerOption(
                    id: provider.rawValue, title: provider.displayName,
                    isSelected: session.provider == provider,
                    action: { SessionActions.setProvider(provider, for: session) })
            })
    }
}
