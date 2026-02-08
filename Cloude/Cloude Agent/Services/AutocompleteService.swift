import Foundation

@MainActor
class AutocompleteService {
    private var currentProcess: Process?

    private var claudePath: String {
        let paths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/claude",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.npm-global/bin/claude"
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "claude"
    }

    func suggest(context: [String], workingDirectory: String?, completion: @escaping ([String]) -> Void) {
        cancel()

        var contextBlock = ""
        if !context.isEmpty {
            contextBlock = context.enumerated().map { i, msg in
                (i % 2 == 0 ? "User: " : "Assistant: ") + msg
            }.joined(separator: "\n")
        }

        let prompt = """
        Given this conversation:
        \(contextBlock)

        Suggest exactly 1 short follow-up message the user might send next. It should be 2-6 words, natural and actionable. Output ONLY a JSON array of 1 string, nothing else. Example: ["Push to git"]
        """

        let process = Process()
        let outputPipe = Pipe()

        let command = "\(claudePath) --model haiku -p \(shellEscape(prompt)) --max-turns 1 --output-format text"

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        if let wd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: wd)
        }
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        var env = ProcessInfo.processInfo.environment
        env["NO_COLOR"] = "1"
        process.environment = env

        currentProcess = process

        let timeoutWork = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                if self?.currentProcess === process && process.isRunning {
                    process.terminate()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeoutWork)

        process.terminationHandler = { [weak self] _ in
            timeoutWork.cancel()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else {
                Task { @MainActor in self?.currentProcess = nil }
                return
            }

            var jsonString = output
            if let start = jsonString.firstIndex(of: "["), let end = jsonString.lastIndex(of: "]") {
                jsonString = String(jsonString[start...end])
            }

            guard let jsonData = jsonString.data(using: .utf8),
                  let suggestions = try? JSONDecoder().decode([String].self, from: jsonData),
                  !suggestions.isEmpty else {
                Task { @MainActor in self?.currentProcess = nil }
                return
            }

            let filtered = Array(suggestions.prefix(1).filter { !$0.isEmpty })
            Task { @MainActor in
                guard self?.currentProcess === process else { return }
                self?.currentProcess = nil
                if !filtered.isEmpty { completion(filtered) }
            }
        }

        do {
            try process.run()
        } catch {
            Log.error("Suggestions failed to start: \(error)")
            currentProcess = nil
        }
    }

    private static let availableSymbols = [
        "message", "message.fill", "bubble.left", "bubble.left.fill", "bubble.right", "bubble.right.fill", "bubble.left.and.bubble.right", "bubble.left.and.bubble.right.fill", "phone", "phone.fill", "video", "video.fill", "envelope", "envelope.fill", "paperplane", "paperplane.fill", "bell", "bell.fill", "megaphone", "megaphone.fill",
        "sun.max", "sun.max.fill", "moon", "moon.fill", "moon.stars", "moon.stars.fill", "cloud", "cloud.fill", "cloud.sun", "cloud.sun.fill", "cloud.moon", "cloud.moon.fill", "cloud.bolt", "cloud.bolt.fill", "cloud.rain", "cloud.rain.fill", "cloud.snow", "cloud.snow.fill", "snowflake", "thermometer.sun", "thermometer.snowflake",
        "pencil", "pencil.circle.fill", "folder", "folder.fill", "paperclip", "link", "book", "book.fill", "bookmark", "bookmark.fill", "tag", "tag.fill", "camera", "camera.fill", "photo", "photo.fill", "film", "film.fill", "music.note", "music.note.list", "headphones", "lightbulb", "lightbulb.fill", "lamp.desk", "flashlight.on.fill", "battery.100", "cpu", "memorychip", "keyboard", "printer", "tv", "display",
        "iphone", "ipad", "laptopcomputer", "desktopcomputer", "server.rack", "externaldrive", "internaldrive", "opticaldiscdrive", "pc", "macpro.gen3", "applewatch", "airpods", "homepod", "hifispeaker", "gamecontroller", "gamecontroller.fill",
        "wifi", "antenna.radiowaves.left.and.right", "dot.radiowaves.left.and.right", "network", "globe", "globe.americas", "globe.europe.africa", "globe.asia.australia", "airplane", "car", "car.fill", "bus", "tram", "bicycle", "scooter", "fuelpump", "bolt.car", "location", "location.fill", "map", "map.fill", "mappin", "mappin.circle.fill",
        "leaf", "leaf.fill", "tree", "tree.fill", "mountain.2", "mountain.2.fill", "flame", "flame.fill", "drop", "drop.fill", "bolt", "bolt.fill", "tornado", "hurricane", "rainbow", "sparkles", "star", "star.fill", "sun.horizon", "sun.horizon.fill",
        "heart", "heart.fill", "heart.circle", "heart.circle.fill", "bolt.heart", "bolt.heart.fill", "cross", "cross.fill", "pills", "pills.fill", "medical.thermometer", "bandage", "bandage.fill", "syringe", "facemask", "lungs", "lungs.fill", "brain.head.profile", "figure.walk", "figure.run", "figure.yoga", "dumbbell", "dumbbell.fill", "sportscourt", "tennisball",
        "cart", "cart.fill", "bag", "bag.fill", "creditcard", "creditcard.fill", "dollarsign.circle", "dollarsign.circle.fill", "giftcard", "giftcard.fill", "banknote", "banknote.fill", "building.columns", "building.columns.fill", "storefront", "storefront.fill", "basket", "basket.fill", "barcode", "qrcode",
        "clock", "clock.fill", "alarm", "alarm.fill", "stopwatch", "stopwatch.fill", "timer", "hourglass", "hourglass.bottomhalf.filled", "hourglass.tophalf.filled", "calendar", "calendar.circle", "calendar.circle.fill", "calendar.badge.plus", "calendar.badge.clock",
        "play", "play.fill", "play.circle", "play.circle.fill", "pause", "pause.fill", "stop", "stop.fill", "record.circle", "record.circle.fill", "backward", "backward.fill", "forward", "forward.fill", "shuffle", "repeat", "speaker", "speaker.fill", "speaker.wave.3", "speaker.wave.3.fill", "music.mic", "guitars", "pianokeys", "theatermasks", "theatermasks.fill", "ticket", "ticket.fill",
        "pencil.circle", "square.and.pencil", "highlighter", "scribble", "lasso", "trash", "trash.fill", "doc", "doc.fill", "doc.text", "doc.text.fill", "clipboard", "clipboard.fill", "list.bullet", "list.number", "checklist", "text.alignleft", "text.aligncenter", "text.alignright", "bold", "italic", "underline",
        "arrow.up", "arrow.down", "arrow.left", "arrow.right", "arrow.up.circle.fill", "arrow.down.circle.fill", "arrow.left.circle.fill", "arrow.right.circle.fill", "arrow.clockwise", "arrow.counterclockwise", "arrow.triangle.2.circlepath", "arrow.up.arrow.down", "arrow.left.arrow.right", "arrow.uturn.left", "arrow.uturn.right", "chevron.up", "chevron.down", "chevron.left", "chevron.right",
        "circle", "circle.fill", "square", "square.fill", "triangle", "triangle.fill", "diamond", "diamond.fill", "hexagon", "hexagon.fill", "pentagon", "pentagon.fill", "seal", "seal.fill", "shield", "shield.fill", "app", "app.fill",
        "plus", "minus", "multiply", "divide", "equal", "lessthan", "greaterthan", "number", "percent", "sum", "x.squareroot", "function", "plusminus", "chevron.left.forwardslash.chevron.right",
        "lock", "lock.fill", "lock.open", "lock.open.fill", "key", "key.fill", "eye", "eye.fill", "eye.slash", "eye.slash.fill", "hand.raised", "hand.raised.fill", "hand.thumbsup", "hand.thumbsup.fill", "hand.thumbsdown", "hand.thumbsdown.fill", "exclamationmark.shield", "exclamationmark.shield.fill", "checkmark.shield", "checkmark.shield.fill",
        "terminal", "terminal.fill", "apple.terminal", "apple.terminal.fill", "hammer", "hammer.fill", "wrench", "wrench.fill", "screwdriver", "screwdriver.fill", "wrench.and.screwdriver", "wrench.and.screwdriver.fill", "gearshape", "gearshape.fill", "gearshape.2", "gearshape.2.fill", "ant", "ant.fill", "ladybug", "ladybug.fill",
        "checkmark", "checkmark.circle", "checkmark.circle.fill", "xmark", "xmark.circle", "xmark.circle.fill", "exclamationmark.triangle", "exclamationmark.triangle.fill", "info.circle", "info.circle.fill", "questionmark.circle", "questionmark.circle.fill", "plus.circle", "plus.circle.fill", "minus.circle", "minus.circle.fill", "flag", "flag.fill", "bell.badge", "bell.badge.fill"
    ]

    func suggestName(text: String, context: [String], completion: @escaping (String, String?) -> Void) {
        var contextBlock = ""
        if !context.isEmpty {
            contextBlock = "\nConversation so far:\n" + context.map { "- \($0.prefix(300))" }.joined(separator: "\n") + "\n"
        }

        let symbolList = Self.availableSymbols.joined(separator: ", ")

        let prompt = """
        You are naming a chat window in a mobile app. The user needs to glance at the name and instantly know what this conversation is about.

        \(contextBlock)
        Latest user message: "\(text)"

        Suggest a short conversation name (1-3 words) that describes what's being worked on or discussed. Be specific and descriptive, not generic or catchy. Good examples: "Auth Bug Fix", "Dark Mode", "Rename Logic", "Memory System". Bad examples: "Spark", "New Chat", "Quick Fix".

        Also pick an SF Symbol icon from this list that best fits the topic:
        \(symbolList)

        Respond with ONLY a JSON object like: {"name": "Short Name", "symbol": "star.fill"}
        You MUST pick a symbol from the list above. Pick something specific and creative, not generic.
        """

        let process = Process()
        let outputPipe = Pipe()

        let command = "\(claudePath) --model sonnet -p \(shellEscape(prompt)) --max-turns 1 --output-format text"

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        var env = ProcessInfo.processInfo.environment
        env["NO_COLOR"] = "1"
        process.environment = env

        let timeoutWork = DispatchWorkItem {
            Task { @MainActor in
                if process.isRunning { process.terminate() }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeoutWork)

        process.terminationHandler = { _ in
            timeoutWork.cancel()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else { return }

            var jsonString = output
            if let start = jsonString.firstIndex(of: "{"), let end = jsonString.lastIndex(of: "}") {
                jsonString = String(jsonString[start...end])
            }

            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let name = json["name"] as? String, !name.isEmpty else { return }

            let symbol = json["symbol"] as? String

            Task { @MainActor in
                completion(name, symbol)
            }
        }

        do {
            try process.run()
        } catch {
            Log.error("Name suggestion failed to start: \(error)")
        }
    }

    func cancel() {
        if let process = currentProcess, process.isRunning {
            process.terminate()
        }
        currentProcess = nil
    }

    private func shellEscape(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
