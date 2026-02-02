//
//  GlobalInputBar.swift
//  Cloude
//

import SwiftUI
import UIKit
import PhotosUI
import Combine
import CloudeShared

struct SlashCommand {
    let name: String
    let description: String
    let icon: String
    let isSkill: Bool
    let resolvesTo: String?
    let parameters: [SkillParameter]

    init(name: String, description: String, icon: String, isSkill: Bool = false, resolvesTo: String? = nil, parameters: [SkillParameter] = []) {
        self.name = name
        self.description = description
        self.icon = icon
        self.isSkill = isSkill
        self.resolvesTo = resolvesTo
        self.parameters = parameters
    }

    var hasParameters: Bool { !parameters.isEmpty }

    static func fromSkill(_ skill: Skill) -> [SlashCommand] {
        let icon = skill.icon ?? "hammer.circle"
        var commands = [SlashCommand(name: skill.name, description: skill.description, icon: icon, isSkill: true, parameters: skill.parameters)]
        for alias in skill.aliases {
            commands.append(SlashCommand(name: alias, description: skill.description, icon: icon, isSkill: true, resolvesTo: skill.name, parameters: skill.parameters))
        }
        return commands
    }
}

private let builtInCommands: [SlashCommand] = [
    SlashCommand(name: "compact", description: "Compress conversation context", icon: "arrow.triangle.2.circlepath"),
    SlashCommand(name: "context", description: "Show token usage", icon: "chart.pie"),
    SlashCommand(name: "cost", description: "Show usage stats", icon: "dollarsign.circle"),
]

struct GlobalInputBar: View {
    @Binding var inputText: String
    @Binding var selectedImageData: Data?
    let isConnected: Bool
    let isWhisperReady: Bool
    let isTranscribing: Bool
    let isRunning: Bool
    let skills: [Skill]
    let onSend: () -> Void
    var onStop: (() -> Void)?
    var onTranscribe: ((Data) -> Void)?

    @State private var selectedItem: PhotosPickerItem?
    @FocusState private var isInputFocused: Bool
    @FocusState private var focusedParamIndex: Int?
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var placeholderIndex = Int.random(in: 0..<20)
    @State private var textFieldId = UUID()
    @State private var swipeOffset: CGFloat = 0
    @State private var horizontalSwipeOffset: CGFloat = 0
    @State private var isSwipingToRecord = false
    @State private var showInputBar = true
    @State private var showRecordingOverlay = false
    @State private var idleTime: Date = Date()
    @State private var showStopButton = false
    @State private var selectedSkillCommand: SlashCommand?
    @State private var parameterValues: [String] = []

    private let swipeThreshold: CGFloat = 60
    private let transitionDuration: Double = 0.15
    private let stopButtonDelay: TimeInterval = 3.0

    private static let placeholders = [
        "Swipe up to record a voice note",
        "Type / to see available commands",
        "Check the Git tab for changes",
        "Long press a message to copy",
        "Swipe between windows below",
        "Try /compact to reduce context",
        "Swipe left here to clear text",
        "Tap the header to switch chats",
        "The heartbeat runs on a schedule",
        "Try /cost to see usage stats"
    ]

    private var placeholder: String {
        Self.placeholders[placeholderIndex % Self.placeholders.count]
    }

    private var primaryCommands: [SlashCommand] {
        builtInCommands + skills.map { SlashCommand.fromSkill($0).first! }
    }

    private var allCommandsWithAliases: [SlashCommand] {
        builtInCommands + skills.flatMap { SlashCommand.fromSkill($0) }
    }

    private var filteredCommands: [SlashCommand] {
        guard inputText.hasPrefix("/") else { return [] }
        let query = String(inputText.dropFirst()).lowercased()
        if query.isEmpty {
            return primaryCommands
        }
        if let match = allCommandsWithAliases.first(where: { $0.name.lowercased() == query }) {
            return [match]
        }
        return primaryCommands.filter { $0.name.lowercased().hasPrefix(query) }
    }

    private var isSlashCommand: Bool {
        inputText.hasPrefix("/")
    }

    var body: some View {
        VStack(spacing: 0) {
            if let skill = selectedSkillCommand, parameterValues.count == skill.parameters.count {
                SkillParameterBar(
                    skill: skill,
                    parameterValues: $parameterValues,
                    focusedIndex: $focusedParamIndex,
                    onCancel: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            selectedSkillCommand = nil
                            parameterValues = []
                            inputText = ""
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if !filteredCommands.isEmpty {
                SlashCommandSuggestions(
                    commands: filteredCommands,
                    onSelect: { command in
                        if command.hasParameters {
                            withAnimation(.easeOut(duration: 0.15)) {
                                selectedSkillCommand = command
                                parameterValues = Array(repeating: "", count: command.parameters.count)
                                inputText = "/\(command.resolvesTo ?? command.name)"
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                focusedParamIndex = 0
                            }
                        } else {
                            inputText = "/\(command.resolvesTo ?? command.name)"
                            onSend()
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            ZStack(alignment: .bottom) {
                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Image(systemName: "photo")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                    }

                    HStack(spacing: 8) {
                        ZStack(alignment: .leading) {
                            if inputText.isEmpty {
                                Text(placeholder)
                                    .foregroundColor(.secondary)
                                    .id(placeholderIndex)
                                    .transition(.opacity)
                            }
                            TextField("", text: $inputText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(1...4)
                                .focused($isInputFocused)
                                .foregroundColor(isSlashCommand ? .cyan : .primary)
                                .onSubmit { if canSend { onSend() } }
                                .id(textFieldId)
                        }

                        if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Button(action: { selectedImageData = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.accentColor)
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .offset(x: -horizontalSwipeOffset * 0.3)
                    .opacity(1 - Double(min(horizontalSwipeOffset, swipeThreshold)) / Double(swipeThreshold) * 0.5)

                    if shouldShowStopButton {
                        Button(action: { onStop?() }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.accentColor.opacity(0.9))
                        }
                    } else {
                        Menu {
                            Button(action: startRecording) {
                                Label("Record", systemImage: "mic.fill")
                            }
                            .disabled(!canRecord)
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 22))
                                .foregroundColor(canSendWithParams ? .accentColor : .accentColor.opacity(0.4))
                        } primaryAction: {
                            sendWithParameters()
                        }
                        .disabled(!canSendWithParams && !canRecord)
                    }
                }
                .opacity((showInputBar && !isTranscribing) ? 1.0 - Double(min(swipeOffset, swipeThreshold)) / Double(swipeThreshold) * 0.7 : 0)
                .animation(.easeOut(duration: transitionDuration), value: showInputBar)
                .animation(.easeOut(duration: transitionDuration), value: isTranscribing)

                if showRecordingOverlay || isSwipingToRecord || isTranscribing {
                    RecordingOverlayView(
                        audioLevel: audioRecorder.audioLevel,
                        isTranscribing: isTranscribing,
                        onStop: stopRecording
                    )
                    .offset(y: (showRecordingOverlay || isTranscribing) ? 0 : max(0, swipeThreshold - swipeOffset))
                    .opacity((showRecordingOverlay || isTranscribing) ? 1 : Double(min(swipeOffset, swipeThreshold)) / Double(swipeThreshold))
                    .animation(.easeOut(duration: transitionDuration), value: showRecordingOverlay)
                    .animation(.easeOut(duration: transitionDuration), value: isTranscribing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .animation(.easeOut(duration: 0.15), value: filteredCommands.map(\.name))
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let verticalDrag = -value.translation.height
                    let horizontalDrag = -value.translation.width

                    if verticalDrag > abs(horizontalDrag) && canRecord && !audioRecorder.isRecording {
                        isSwipingToRecord = true
                        swipeOffset = verticalDrag
                        horizontalSwipeOffset = 0
                    } else if horizontalDrag > abs(verticalDrag) && !inputText.isEmpty {
                        horizontalSwipeOffset = horizontalDrag
                        swipeOffset = 0
                        isSwipingToRecord = false
                    }
                }
                .onEnded { value in
                    let verticalDrag = -value.translation.height
                    let horizontalDrag = -value.translation.width

                    if verticalDrag >= swipeThreshold && canRecord && isSwipingToRecord {
                        startRecording()
                    } else if horizontalDrag >= swipeThreshold && !inputText.isEmpty {
                        withAnimation(.easeOut(duration: 0.15)) {
                            inputText = ""
                            selectedImageData = nil
                        }
                    }

                    withAnimation(.easeOut(duration: 0.2)) {
                        swipeOffset = 0
                        horizontalSwipeOffset = 0
                        isSwipingToRecord = false
                    }
                }
        )
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
            }
        }
        .onChange(of: inputText) { old, new in
            if !old.isEmpty && new.isEmpty {
                placeholderIndex = Int.random(in: 0..<Self.placeholders.count)
                textFieldId = UUID()
            }
        }
        .onReceive(Timer.publish(every: 8, on: .main, in: .common).autoconnect()) { _ in
            if inputText.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    placeholderIndex = (placeholderIndex + 1) % Self.placeholders.count
                }
            }
        }
        .onChange(of: inputText) { _, _ in
            idleTime = Date()
            showStopButton = false
        }
        .onChange(of: isInputFocused) { _, focused in
            if focused {
                showStopButton = false
            } else {
                idleTime = Date()
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if isRunning && !isInputFocused && Date().timeIntervalSince(idleTime) >= stopButtonDelay {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showStopButton = true
                }
            }
        }
        .onChange(of: isRunning) { _, running in
            if !running {
                showStopButton = false
            } else {
                idleTime = Date()
            }
        }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImageData != nil
    }

    private var canSendWithParams: Bool {
        if let skill = selectedSkillCommand {
            let requiredFilled = zip(skill.parameters, parameterValues).allSatisfy { param, value in
                !param.required || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return requiredFilled
        }
        return canSend
    }

    private var shouldShowStopButton: Bool {
        isRunning && showStopButton && !isInputFocused
    }

    private var canRecord: Bool {
        isConnected && isWhisperReady && !audioRecorder.isTranscribing
    }

    private func sendWithParameters() {
        if let skill = selectedSkillCommand {
            let paramText = parameterValues.enumerated().compactMap { idx, value -> String? in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return trimmed
            }.joined(separator: " ")

            if !paramText.isEmpty {
                inputText = "/\(skill.resolvesTo ?? skill.name) \(paramText)"
            }
            selectedSkillCommand = nil
            parameterValues = []
        }
        onSend()
    }

    private func startRecording() {
        audioRecorder.requestPermission { granted in
            if granted {
                UIApplication.shared.isIdleTimerDisabled = true
                withAnimation(.easeOut(duration: transitionDuration)) {
                    showInputBar = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration) {
                    audioRecorder.startRecording()
                    withAnimation(.easeOut(duration: transitionDuration)) {
                        showRecordingOverlay = true
                    }
                }
            }
        }
    }

    private func stopRecording() {
        UIApplication.shared.isIdleTimerDisabled = false
        let data = audioRecorder.stopRecording()
        withAnimation(.easeOut(duration: transitionDuration)) {
            showRecordingOverlay = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration) {
            withAnimation(.easeOut(duration: transitionDuration)) {
                showInputBar = true
            }
            if let data = data {
                onTranscribe?(data)
            }
        }
    }
}

struct SlashCommandSuggestions: View {
    let commands: [SlashCommand]
    let onSelect: (SlashCommand) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(commands, id: \.name) { command in
                    Button(action: { onSelect(command) }) {
                        SkillPill(command: command)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct SkillPill: View {
    let command: SlashCommand

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: command.icon)
                .font(.system(size: 14, weight: .semibold))
            Text("/\(command.name)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(command.isSkill ? skillGradient : builtInGradient)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(command.isSkill ? Color.purple.opacity(0.12) : Color.cyan.opacity(0.12))
                .overlay(
                    command.isSkill ?
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    : nil
                )
        )
    }

    private var skillGradient: LinearGradient {
        LinearGradient(
            colors: [.purple, .pink.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var builtInGradient: LinearGradient {
        LinearGradient(colors: [.cyan], startPoint: .leading, endPoint: .trailing)
    }
}

struct SkillParameterBar: View {
    let skill: SlashCommand
    @Binding var parameterValues: [String]
    var focusedIndex: FocusState<Int?>.Binding

    let onCancel: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Image(systemName: skill.icon)
                        .font(.system(size: 14, weight: .semibold))
                    Text("/\(skill.resolvesTo ?? skill.name)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(skillGradient)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.purple.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )

                ForEach(Array(skill.parameters.enumerated()), id: \.offset) { index, param in
                    if index < parameterValues.count {
                        ParameterInputBubble(
                            parameter: param,
                            value: $parameterValues[index],
                            isFocused: focusedIndex.wrappedValue == index,
                            onTap: { focusedIndex.wrappedValue = index }
                        )
                        .focused(focusedIndex, equals: index)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var skillGradient: LinearGradient {
        LinearGradient(
            colors: [.purple, .pink.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct ParameterInputBubble: View {
    let parameter: SkillParameter
    @Binding var value: String
    let isFocused: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            TextField(parameter.placeholder, text: $value)
                .font(.system(size: 12, design: .monospaced))
                .textFieldStyle(.plain)
                .frame(minWidth: 100, maxWidth: 200)
            if parameter.required && value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: "asterisk")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.pink.opacity(0.6))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.purple.opacity(isFocused ? 0.18 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.purple.opacity(isFocused ? 0.4 : 0.2), lineWidth: 1)
                )
        )
        .onTapGesture(perform: onTap)
    }
}
