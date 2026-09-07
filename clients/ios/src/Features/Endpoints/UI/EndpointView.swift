import SwiftData
import SwiftUI

struct EndpointView: View {
    let existing: Endpoint?
    let canDelete: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @State private var host: String
    @State private var name: String
    @State private var port: Int
    @State private var useTLS: Bool
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
        _name = State(initialValue: existing?.name ?? "")
        _port = State(initialValue: existing?.port ?? 8765)
        _useTLS = State(initialValue: existing?.transportScheme == "https")
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
                TextField("Host name, such as Production or Devbox", text: $name)
                    .appFont(size: ThemeTokens.Text.l, weight: .medium)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(ThemeTokens.Spacing.m)
                    .background(theme.palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
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
                            .foregroundColor(ThemeColor.secondary)
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                    Text("Host or URL")
                        .appFont(size: ThemeTokens.Text.s, weight: .medium)
                        .foregroundColor(ThemeColor.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: ThemeTokens.Spacing.m) {
                        Image(systemName: "server.rack")
                            .appFont(size: ThemeTokens.Icon.m)
                            .foregroundColor(ThemeColor.blue)

                        TextField("https://remote.example.com", text: $host)
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
                        .foregroundColor(ThemeColor.secondary)
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

                Toggle("HTTPS", isOn: $useTLS)
                    .padding(ThemeTokens.Spacing.m)
                    .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                    Text("Auth Token")
                        .appFont(size: ThemeTokens.Text.s, weight: .medium)
                        .foregroundColor(ThemeColor.secondary)
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
                                .foregroundColor(ThemeColor.secondary)
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
                .accessibilityLabel("Save host")
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
        isProbing || EndpointAddress(input: host, port: port, scheme: useTLS ? "https" : "http") == nil
            || authKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        authKey = authKey.trimmingCharacters(in: .whitespacesAndNewlines)
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        saveError = nil
        isProbing = true
        if let address = EndpointAddress(input: host, port: port, scheme: useTLS ? "https" : "http") {
            let result = await EndpointService.probe(
                host: address.host, port: address.port, authKey: authKey, scheme: address.scheme)
            isProbing = false
            switch result {
            case .reachable:
                if let existing {
                    EndpointActions.update(
                        existing, host: address.host, port: address.port, name: name, symbolName: symbolName,
                        authKey: authKey, scheme: address.scheme)
                } else {
                    EndpointActions.create(
                        into: context, host: address.host, port: address.port, name: name, symbolName: symbolName,
                        authKey: authKey, scheme: address.scheme)
                }
                PushNotificationCoordinator.shared.registerAll()
                withAnimation(.easeOut(duration: ThemeTokens.Duration.s)) { didSucceed = true }
                try? await Task.sleep(nanoseconds: 400_000_000)
                dismiss()
            case .unauthorized:
                withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                    saveError = "Host found · token rejected"
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
}
