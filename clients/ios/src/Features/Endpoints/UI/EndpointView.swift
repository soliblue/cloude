import SwiftData
import SwiftUI

struct EndpointView: View {
    let existing: Endpoint?
    let canDelete: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @State private var host: String
    @State private var port: Int
    @State private var symbolName: String
    @State private var authKey: String
    @State private var isDeleteConfirmPresented = false
    @State private var isProbing = false
    @State private var isSymbolPickerPresented = false
    @State private var isTokenVisible = false
    @State private var saveError: String?
    @State private var didSucceed = false

    init(existing: Endpoint? = nil, canDelete: Bool = false) {
        self.existing = existing
        self.canDelete = canDelete
        _host = State(initialValue: existing?.host ?? "")
        _port = State(initialValue: existing?.port ?? 8765)
        _symbolName = State(
            initialValue: existing?.symbolName
                ?? EndpointsSymbolCatalog.symbols.randomElement() ?? Endpoint.defaultSymbol
        )
        _authKey = State(
            initialValue: existing.map { SecureStorage.get(account: $0.id.uuidString) ?? "" } ?? "")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                HStack(spacing: ThemeTokens.Spacing.m) {
                    IconPillButton(symbol: symbolName, tint: ThemeColor.rust) {
                        isSymbolPickerPresented = true
                    }

                    VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                        Text("Symbol")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                            .foregroundColor(.primary)
                        Text(symbolName)
                            .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                    Text("Host")
                        .appFont(size: ThemeTokens.Text.s, weight: .medium)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: ThemeTokens.Spacing.m) {
                        Image(systemName: "server.rack")
                            .appFont(size: ThemeTokens.Icon.m)
                            .foregroundColor(ThemeColor.blue)

                        TextField("remote.example.com", text: $host)
                            .appFont(size: ThemeTokens.Text.m)
                            .textFieldStyle(.plain)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                    .padding(ThemeTokens.Spacing.m)
                    .background(theme.palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
                }

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                    Text("Port")
                        .appFont(size: ThemeTokens.Text.s, weight: .medium)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: ThemeTokens.Spacing.m) {
                        Image(systemName: "number")
                            .appFont(size: ThemeTokens.Icon.m)
                            .foregroundColor(ThemeColor.blue)

                        TextField("8765", value: $port, format: .number.grouping(.never))
                            .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                            .textFieldStyle(.plain)
                            .keyboardType(.numberPad)
                    }
                    .padding(ThemeTokens.Spacing.m)
                    .background(theme.palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
                }

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                    Text("Auth Token")
                        .appFont(size: ThemeTokens.Text.s, weight: .medium)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: ThemeTokens.Spacing.m) {
                        Image(systemName: "key.fill")
                            .appFont(size: ThemeTokens.Icon.m)
                            .foregroundColor(ThemeColor.orange)

                        Group {
                            if isTokenVisible {
                                TextField("Auth Token", text: $authKey)
                            } else {
                                SecureField("Auth Token", text: $authKey)
                            }
                        }
                        .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                        .textFieldStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        Button {
                            isTokenVisible.toggle()
                        } label: {
                            Image(systemName: isTokenVisible ? "eye.slash.fill" : "eye.fill")
                                .appFont(size: ThemeTokens.Text.m)
                                .foregroundColor(.secondary)
                                .frame(width: ThemeTokens.Text.m, height: ThemeTokens.Text.m)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(ThemeTokens.Spacing.m)
                    .background(theme.palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))

                    if let saveError {
                        Text(saveError)
                            .appFont(size: ThemeTokens.Text.s, weight: .medium)
                            .foregroundColor(ThemeColor.danger)
                            .padding(.horizontal, ThemeTokens.Spacing.xs)
                            .transition(.opacity)
                    }
                }
            }
        }
        .padding(ThemeTokens.Spacing.m)
        .background(theme.palette.background)
        .themedNavChrome()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await save() }
                } label: {
                    saveIcon
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .foregroundColor(didSucceed ? ThemeColor.success : .primary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: ThemeTokens.Text.m, height: ThemeTokens.Text.m)
                        .opacity(isSaveDisabled ? ThemeTokens.Opacity.m : 1)
                }
                .disabled(isSaveDisabled)
            }
            if existing != nil, canDelete {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        isDeleteConfirmPresented = true
                    } label: {
                        Image(systemName: "trash")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                            .foregroundColor(ThemeColor.danger)
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete \(host.isEmpty ? "endpoint" : host)?",
            isPresented: $isDeleteConfirmPresented
        ) {
            Button("Delete", role: .destructive) {
                if let existing {
                    EndpointActions.remove(existing, context: context)
                }
                dismiss()
            }
        }
        .sheet(isPresented: $isSymbolPickerPresented) {
            EndpointsSymbolPicker(selectedSymbol: $symbolName)
        }
        .preferredColorScheme(theme.palette.colorScheme)
    }

    private var isSaveDisabled: Bool {
        isProbing || host.isEmpty || authKey.isEmpty
    }

    @ViewBuilder
    private var saveIcon: some View {
        if isProbing {
            ProgressView().controlSize(.small)
        } else {
            Image(systemName: "checkmark")
        }
    }

    private func save() async {
        saveError = nil
        isProbing = true
        let result = await EndpointService.probe(host: host, port: port, authKey: authKey)
        isProbing = false
        switch result {
        case .reachable:
            if let existing {
                EndpointActions.update(
                    existing, host: host, port: port, symbolName: symbolName, authKey: authKey)
            } else {
                EndpointActions.create(
                    into: context, host: host, port: port, symbolName: symbolName, authKey: authKey)
            }
            withAnimation(.easeOut(duration: ThemeTokens.Duration.s)) { didSucceed = true }
            try? await Task.sleep(nanoseconds: 400_000_000)
            dismiss()
        case .unauthorized:
            withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                saveError = "Mac found · token rejected"
            }
        case .unreachable:
            withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                saveError = "Unreachable · check host and port"
            }
        case .invalid:
            withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                saveError = "Invalid response · check host and port"
            }
        }
    }
}
