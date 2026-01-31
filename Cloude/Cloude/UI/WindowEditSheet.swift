//
//  WindowEditSheet.swift
//  Cloude
//

import SwiftUI

struct WindowEditSheet: View {
    let window: ChatWindow
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var windowManager: WindowManager
    let onSelectConversation: () -> Void
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var symbol: String = ""
    @State private var showSymbolPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Button(action: { showSymbolPicker = true }) {
                        Image(systemName: symbol.isEmpty ? "circle.dashed" : symbol)
                            .font(.system(size: 24))
                            .frame(width: 56, height: 56)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    TextField("Name", text: $name)
                        .font(.title3)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                HStack(spacing: 12) {
                    Button(action: onSelectConversation) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                            Text("Change")
                        }
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    if windowManager.windows.count > 1 {
                        Button(action: {
                            windowManager.removeWindow(window.id)
                            onDismiss()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove")
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("Edit Window")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        windowManager.setWindowName(window.id, name: name.isEmpty ? nil : name)
                        windowManager.setWindowEmoji(window.id, emoji: symbol.isEmpty ? nil : symbol)
                        onDismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .sheet(isPresented: $showSymbolPicker) {
                SymbolPickerSheet(selectedSymbol: $symbol)
            }
        }
        .presentationDetents([.height(280)])
        .onAppear {
            name = window.customName ?? ""
            symbol = window.emoji ?? ""
        }
    }
}

struct SymbolPickerSheet: View {
    @Binding var selectedSymbol: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private static let symbolCategories: [(String, [String])] = [
        ("Communication", ["message", "message.fill", "bubble.left", "bubble.left.fill", "bubble.right", "bubble.right.fill", "bubble.left.and.bubble.right", "bubble.left.and.bubble.right.fill", "phone", "phone.fill", "video", "video.fill", "envelope", "envelope.fill", "paperplane", "paperplane.fill", "bell", "bell.fill", "megaphone", "megaphone.fill"]),
        ("Weather", ["sun.max", "sun.max.fill", "moon", "moon.fill", "moon.stars", "moon.stars.fill", "cloud", "cloud.fill", "cloud.sun", "cloud.sun.fill", "cloud.moon", "cloud.moon.fill", "cloud.bolt", "cloud.bolt.fill", "cloud.rain", "cloud.rain.fill", "cloud.snow", "cloud.snow.fill", "snowflake", "thermometer.sun", "thermometer.snowflake"]),
        ("Objects", ["pencil", "pencil.circle.fill", "folder", "folder.fill", "paperclip", "link", "book", "book.fill", "bookmark", "bookmark.fill", "tag", "tag.fill", "camera", "camera.fill", "photo", "photo.fill", "film", "music.note", "music.note.list", "headphones", "lightbulb", "lightbulb.fill", "lamp.desk", "flashlight.on.fill", "battery.100", "cpu", "memorychip", "keyboard", "printer", "tv", "display"]),
        ("Devices", ["iphone", "ipad", "laptopcomputer", "desktopcomputer", "server.rack", "externaldrive", "internaldrive", "opticaldiscdrive", "display", "pc", "macpro.gen3", "applewatch", "airpods", "homepod", "hifispeaker", "gamecontroller", "gamecontroller.fill"]),
        ("Connectivity", ["wifi", "antenna.radiowaves.left.and.right", "dot.radiowaves.left.and.right", "network", "globe", "globe.americas", "globe.europe.africa", "globe.asia.australia", "airplane", "car", "car.fill", "bus", "tram", "bicycle", "scooter", "fuelpump", "bolt.car", "location", "location.fill", "map", "map.fill", "mappin", "mappin.circle.fill"]),
        ("Nature", ["leaf", "leaf.fill", "tree", "tree.fill", "mountain.2", "mountain.2.fill", "flame", "flame.fill", "drop", "drop.fill", "bolt", "bolt.fill", "tornado", "hurricane", "rainbow", "sparkles", "star", "star.fill", "moon.stars.fill", "sun.horizon", "sun.horizon.fill"]),
        ("Health", ["heart", "heart.fill", "heart.circle", "heart.circle.fill", "bolt.heart", "bolt.heart.fill", "cross", "cross.fill", "pills", "pills.fill", "medical.thermometer", "bandage", "bandage.fill", "syringe", "facemask", "lungs", "lungs.fill", "brain.head.profile", "figure.walk", "figure.run", "figure.yoga", "dumbbell", "dumbbell.fill", "sportscourt", "tennisball"]),
        ("Commerce", ["cart", "cart.fill", "bag", "bag.fill", "creditcard", "creditcard.fill", "dollarsign.circle", "dollarsign.circle.fill", "giftcard", "giftcard.fill", "banknote", "banknote.fill", "building.columns", "building.columns.fill", "storefront", "storefront.fill", "basket", "basket.fill", "tag", "tag.fill", "barcode", "qrcode"]),
        ("Time", ["clock", "clock.fill", "alarm", "alarm.fill", "stopwatch", "stopwatch.fill", "timer", "hourglass", "hourglass.bottomhalf.filled", "hourglass.tophalf.filled", "calendar", "calendar.circle", "calendar.circle.fill", "calendar.badge.plus", "calendar.badge.clock"]),
        ("Media", ["play", "play.fill", "play.circle", "play.circle.fill", "pause", "pause.fill", "stop", "stop.fill", "record.circle", "record.circle.fill", "backward", "backward.fill", "forward", "forward.fill", "shuffle", "repeat", "speaker", "speaker.fill", "speaker.wave.3", "speaker.wave.3.fill", "music.mic", "guitars", "pianokeys", "theatermasks", "theatermasks.fill", "film", "film.fill", "ticket", "ticket.fill"]),
        ("Editing", ["pencil", "pencil.circle", "pencil.circle.fill", "square.and.pencil", "highlighter", "scribble", "lasso", "trash", "trash.fill", "folder", "folder.fill", "doc", "doc.fill", "doc.text", "doc.text.fill", "clipboard", "clipboard.fill", "list.bullet", "list.number", "checklist", "text.alignleft", "text.aligncenter", "text.alignright", "bold", "italic", "underline"]),
        ("Arrows", ["arrow.up", "arrow.down", "arrow.left", "arrow.right", "arrow.up.circle.fill", "arrow.down.circle.fill", "arrow.left.circle.fill", "arrow.right.circle.fill", "arrow.clockwise", "arrow.counterclockwise", "arrow.triangle.2.circlepath", "arrow.up.arrow.down", "arrow.left.arrow.right", "arrow.uturn.left", "arrow.uturn.right", "chevron.up", "chevron.down", "chevron.left", "chevron.right"]),
        ("Shapes", ["circle", "circle.fill", "square", "square.fill", "triangle", "triangle.fill", "diamond", "diamond.fill", "hexagon", "hexagon.fill", "pentagon", "pentagon.fill", "seal", "seal.fill", "shield", "shield.fill", "star", "star.fill", "heart", "heart.fill", "app", "app.fill"]),
        ("Math & Logic", ["plus", "minus", "multiply", "divide", "equal", "lessthan", "greaterthan", "number", "percent", "sum", "x.squareroot", "function", "plusminus", "chevron.left.forwardslash.chevron.right"]),
        ("Privacy", ["lock", "lock.fill", "lock.open", "lock.open.fill", "key", "key.fill", "eye", "eye.fill", "eye.slash", "eye.slash.fill", "hand.raised", "hand.raised.fill", "hand.thumbsup", "hand.thumbsup.fill", "hand.thumbsdown", "hand.thumbsdown.fill", "exclamationmark.shield", "exclamationmark.shield.fill", "checkmark.shield", "checkmark.shield.fill"]),
        ("Development", ["chevron.left.forwardslash.chevron.right", "terminal", "terminal.fill", "apple.terminal", "apple.terminal.fill", "hammer", "hammer.fill", "wrench", "wrench.fill", "screwdriver", "screwdriver.fill", "wrench.and.screwdriver", "wrench.and.screwdriver.fill", "gearshape", "gearshape.fill", "gearshape.2", "gearshape.2.fill", "ant", "ant.fill", "ladybug", "ladybug.fill", "leaf", "leaf.fill"]),
        ("Status", ["checkmark", "checkmark.circle", "checkmark.circle.fill", "xmark", "xmark.circle", "xmark.circle.fill", "exclamationmark.triangle", "exclamationmark.triangle.fill", "info.circle", "info.circle.fill", "questionmark.circle", "questionmark.circle.fill", "plus.circle", "plus.circle.fill", "minus.circle", "minus.circle.fill", "flag", "flag.fill", "bell.badge", "bell.badge.fill"])
    ]

    private var filteredCategories: [(String, [String])] {
        if searchText.isEmpty {
            return Self.symbolCategories
        }
        let query = searchText.lowercased()
        return Self.symbolCategories.compactMap { category, symbols in
            let filtered = symbols.filter { $0.lowercased().contains(query) }
            return filtered.isEmpty ? nil : (category, filtered)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(filteredCategories, id: \.0) { category, symbols in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category)
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 12) {
                                ForEach(symbols, id: \.self) { symbol in
                                    Button(action: {
                                        selectedSymbol = symbol
                                        dismiss()
                                    }) {
                                        Image(systemName: symbol)
                                            .font(.system(size: 22))
                                            .frame(width: 44, height: 44)
                                            .background(selectedSymbol == symbol ? Color.accentColor.opacity(0.2) : Color.clear)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .searchable(text: $searchText, prompt: "Search symbols")
            .navigationTitle("Choose Symbol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
                if !selectedSymbol.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button {
                            selectedSymbol = ""
                            dismiss()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
