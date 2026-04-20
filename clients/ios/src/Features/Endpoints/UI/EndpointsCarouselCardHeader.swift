import SwiftUI

struct EndpointsCarouselCardHeader: View {
    @Binding var endpoint: Endpoint
    let authKey: String
    @EnvironmentObject private var store: EndpointsStore
    @State private var isSymbolPickerPresented = false
    @State private var isDeleteConfirmPresented = false
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.m) {
            Button { isSymbolPickerPresented = true } label: {
                Image(systemName: endpoint.symbolName)
                    .appFont(size: ThemeTokens.Icon.l)
                    .foregroundColor(.accentColor)
                    .frame(width: ThemeTokens.Size.l, height: ThemeTokens.Size.l)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isSymbolPickerPresented) {
                EndpointsSymbolPicker(selectedSymbol: $endpoint.symbolName)
            }

            HStack(spacing: ThemeTokens.Spacing.s) {
                Circle()
                    .fill(endpoint.status.color)
                    .frame(width: ThemeTokens.Size.s, height: ThemeTokens.Size.s)
                Text(endpoint.status.label)
                    .appFont(size: ThemeTokens.Text.m)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if store.endpoints.count > 1 {
                Button { isDeleteConfirmPresented = true } label: {
                    Image(systemName: "trash")
                        .appFont(size: ThemeTokens.Icon.s)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .confirmationDialog("Delete \(endpoint.host.isEmpty ? "endpoint" : endpoint.host)?", isPresented: $isDeleteConfirmPresented) {
                    Button("Delete", role: .destructive) {
                        SecureStorage.delete(account: endpoint.id.uuidString)
                        store.endpoints.removeAll { $0.id == endpoint.id }
                    }
                }

                Divider().frame(height: ThemeTokens.Icon.m)
            }

            Button {
                Task { await EndpointService.ping(id: endpoint.id, authKey: authKey, store: store) }
            } label: {
                Image(systemName: "power")
                    .appFont(size: ThemeTokens.Icon.m, weight: .medium)
                    .foregroundStyle(endpoint.status == .reachable || endpoint.status == .checking ? Color.accentColor : .secondary)
                    .opacity(isPulsing ? ThemeTokens.Opacity.m : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(endpoint.host.isEmpty || authKey.isEmpty)
            .onChange(of: endpoint.status) { _, status in
                if status == .checking {
                    withAnimation(.easeInOut(duration: ThemeTokens.Duration.l).repeatForever(autoreverses: true)) { isPulsing = true }
                } else {
                    withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) { isPulsing = false }
                }
            }
        }
    }
}
