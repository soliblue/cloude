import SwiftUI
import CloudeShared

struct WindowEditForm: View {
    let window: ChatWindow
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var environmentStore: EnvironmentStore
    let onSelectConversation: (Conversation) -> Void

    @State private var name: String = ""
    @State private var symbol: String = ""
    @State private var showSymbolPicker = false
    @State private var showBranchPicker = false
    @State private var branches: [String] = []
    @State private var branchSearch: String = ""
    @State var visibleCount = 20

    private var conversation: Conversation? {
        window.conversation(in: conversationStore)
    }

    private var openInOtherWindows: Set<UUID> {
        windowManager.conversationIds(excludingWindow: window.id)
    }

    var allConversations: [Conversation] {
        conversationStore.listableConversations
            .filter { $0.id != conversation?.id && !openInOtherWindows.contains($0.id) }
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    private var canChangeFolder: Bool {
        guard let conv = conversation else { return false }
        return conv.messages.isEmpty && conv.sessionId == nil
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Button(action: { showSymbolPicker = true }) {
                    Image.safeSymbol(symbol.nilIfEmpty, fallback: "circle.dashed")
                        .font(.system(size: 24))
                        .frame(width: 48, height: 48)
                        .background(Color.themeSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)

                TextField("Name", text: $name)
                    .font(.title3)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color.themeSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .onChange(of: name) { _, newValue in
                        if let conv = conversation, !newValue.isEmpty {
                            conversationStore.renameConversation(conv, to: newValue)
                        }
                    }
            }

            if let conv = conversation {
                EnvironmentFolderPicker(
                    environmentStore: environmentStore,
                    connection: connection,
                    conversationStore: conversationStore,
                    conversation: conv,
                    editable: canChangeFolder
                )

                branchRow(conv)
            }

            conversationListSection()
        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerSheet(selectedSymbol: $symbol)
        }
        .sheet(isPresented: $showBranchPicker) {
            branchPickerSheet()
        }
        .onChange(of: symbol) { _, newValue in
            if let conv = conversation {
                conversationStore.setConversationSymbol(conv, symbol: newValue.nilIfEmpty)
            }
        }
        .onAppear {
            name = conversation?.name ?? ""
            symbol = conversation?.symbol ?? ""
        }
        .onChange(of: conversation?.id) { _, _ in
            name = conversation?.name ?? ""
            symbol = conversation?.symbol ?? ""
        }
        .onReceive(connection.events) { event in
            if case .branchList(let list, _) = event {
                branches = list
            }
        }
    }

    @ViewBuilder
    func branchRow(_ conv: Conversation) -> some View {
        HStack {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            if let branch = conv.attachedBranch {
                Text(branch)
                    .font(.subheadline.monospaced())
                    .lineLimit(1)

                Spacer()

                Button {
                    conversationStore.detachBranch(conv)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Text("Branch")
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    if let wd = conv.workingDirectory {
                        connection.listBranches(workingDirectory: wd, environmentId: conv.environmentId)
                    }
                    showBranchPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color.themeSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    func branchPickerSheet() -> some View {
        NavigationStack {
            List {
                ForEach(filteredBranches, id: \.self) { branch in
                    Button {
                        if let conv = conversation, let wd = conv.originalWorkingDirectory ?? conv.workingDirectory {
                            connection.attachBranch(branch: branch, workingDirectory: wd, conversationId: conv.id, environmentId: conv.environmentId)
                        }
                        showBranchPicker = false
                    } label: {
                        Text(branch)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $branchSearch, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Attach Branch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showBranchPicker = false } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            branchSearch = ""
        }
    }

    var filteredBranches: [String] {
        branchSearch.isEmpty ? branches : branches.filter { $0.localizedCaseInsensitiveContains(branchSearch) }
    }
}
