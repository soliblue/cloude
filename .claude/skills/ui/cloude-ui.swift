import Cocoa
import ApplicationServices

struct UIElement: Codable {
    let id: Int
    let role: String
    let label: String
    let value: String
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let actions: [String]
}

func getRunningApps() -> [(String, pid_t)] {
    NSWorkspace.shared.runningApplications
        .filter { $0.activationPolicy == .regular }
        .compactMap { app in
            if let name = app.localizedName { return (name, app.processIdentifier) }
            return nil
        }
}

func getFrontmostApp() -> (String, pid_t)? {
    if let app = NSWorkspace.shared.frontmostApplication, let name = app.localizedName {
        return (name, app.processIdentifier)
    }
    return nil
}

func getAttributeValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    return value
}

func getStringAttribute(_ element: AXUIElement, _ attribute: String) -> String {
    if let value = getAttributeValue(element, attribute) {
        return "\(value)"
    }
    return ""
}

func getPosition(_ element: AXUIElement) -> (Int, Int)? {
    var pos: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXPositionAttribute as String as CFString, &pos)
    if let pos = pos {
        var point = CGPoint.zero
        AXValueGetValue(pos as! AXValue, .cgPoint, &point)
        return (Int(point.x), Int(point.y))
    }
    return nil
}

func getSize(_ element: AXUIElement) -> (Int, Int)? {
    var size: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXSizeAttribute as String as CFString, &size)
    if let size = size {
        var s = CGSize.zero
        AXValueGetValue(size as! AXValue, .cgSize, &s)
        return (Int(s.width), Int(s.height))
    }
    return nil
}

func getActions(_ element: AXUIElement) -> [String] {
    var actions: CFArray?
    AXUIElementCopyActionNames(element, &actions)
    return (actions as? [String]) ?? []
}

var elementCounter = 0
var elementMap: [Int: AXUIElement] = [:]

func collectElements(_ element: AXUIElement, depth: Int = 0, maxDepth: Int = 10) -> [UIElement] {
    if depth > maxDepth { return [] }
    var results: [UIElement] = []

    let role = getStringAttribute(element, kAXRoleAttribute as String)
    let label = getStringAttribute(element, kAXTitleAttribute as String)
    let desc = getStringAttribute(element, kAXDescriptionAttribute as String)
    let value = getStringAttribute(element, kAXValueAttribute as String)
    let actions = getActions(element)
    let pos = getPosition(element)
    let size = getSize(element)

    let interactiveRoles: Set<String> = [
        "AXButton", "AXTextField", "AXTextArea", "AXCheckBox",
        "AXRadioButton", "AXPopUpButton", "AXComboBox", "AXSlider",
        "AXMenuItem", "AXMenuBarItem", "AXLink", "AXTab",
        "AXStaticText", "AXImage", "AXGroup", "AXToolbar",
        "AXList", "AXTable", "AXRow", "AXCell", "AXSwitch"
    ]

    let displayLabel = label.isEmpty ? desc : label
    let isInteractive = interactiveRoles.contains(role) || !actions.isEmpty

    if isInteractive && pos != nil && size != nil {
        elementCounter += 1
        elementMap[elementCounter] = element
        let (x, y) = pos!
        let (w, h) = size!

        let truncatedValue = value.count > 200 ? String(value.prefix(200)) + "..." : value

        results.append(UIElement(
            id: elementCounter,
            role: role.replacingOccurrences(of: "AX", with: ""),
            label: displayLabel,
            value: truncatedValue,
            x: x, y: y, width: w, height: h,
            actions: actions
        ))
    }

    if let children = getAttributeValue(element, kAXChildrenAttribute as String) as? [AXUIElement] {
        for child in children {
            results.append(contentsOf: collectElements(child, depth: depth + 1, maxDepth: maxDepth))
        }
    }

    return results
}

func cmdSee(appName: String?) {
    let pid: pid_t
    let name: String

    if let appName = appName {
        if let match = getRunningApps().first(where: { $0.0.lowercased().contains(appName.lowercased()) }) {
            (name, pid) = match
        } else {
            print("ERROR: No running app matching '\(appName)'")
            print("Running apps: \(getRunningApps().map { $0.0 }.joined(separator: ", "))")
            exit(1)
        }
    } else {
        if let front = getFrontmostApp() {
            (name, pid) = front
        } else {
            print("ERROR: No frontmost app found")
            exit(1)
        }
    }

    let appElement = AXUIElementCreateApplication(pid)
    elementCounter = 0
    elementMap = [:]
    let elements = collectElements(appElement)

    var output: [String: Any] = [
        "app": name,
        "pid": pid,
        "element_count": elements.count
    ]

    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    if let data = try? encoder.encode(elements), let json = String(data: data, encoding: .utf8) {
        output["elements"] = json
    }

    print("App: \(name) (pid \(pid))")
    print("Elements: \(elements.count)")
    print("---")

    let encoder2 = JSONEncoder()
    encoder2.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder2.encode(elements), let json = String(data: data, encoding: .utf8) {
        print(json)
    }
}

func cmdClick(elementId: Int, appName: String?) {
    let pid: pid_t

    if let appName = appName {
        if let match = getRunningApps().first(where: { $0.0.lowercased().contains(appName.lowercased()) }) {
            pid = match.1
        } else {
            print("ERROR: No running app matching '\(appName)'")
            exit(1)
        }
    } else {
        if let front = getFrontmostApp() {
            pid = front.1
        } else {
            print("ERROR: No frontmost app found")
            exit(1)
        }
    }

    let appElement = AXUIElementCreateApplication(pid)
    elementCounter = 0
    elementMap = [:]
    _ = collectElements(appElement)

    if let element = elementMap[elementId] {
        let actions = getActions(element)
        let label = getStringAttribute(element, kAXTitleAttribute as String)

        if actions.contains(kAXPressAction as String) {
            AXUIElementPerformAction(element, kAXPressAction as CFString)
            print("Clicked: [\(elementId)] \(label)")
        } else if actions.contains(kAXConfirmAction as String) {
            AXUIElementPerformAction(element, kAXConfirmAction as CFString)
            print("Confirmed: [\(elementId)] \(label)")
        } else if let firstAction = actions.first {
            AXUIElementPerformAction(element, firstAction as CFString)
            print("Performed \(firstAction) on: [\(elementId)] \(label)")
        } else {
            print("ERROR: Element [\(elementId)] has no actions")
            exit(1)
        }
    } else {
        print("ERROR: Element [\(elementId)] not found. Run 'see' first to get current element IDs.")
        exit(1)
    }
}

func cmdType(text: String) {
    let src = CGEventSource(stateID: .hidSystemState)
    for char in text {
        var utf16 = Array(String(char).utf16)
        let event = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
        event?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        event?.post(tap: .cghidEventTap)

        let upEvent = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
        upEvent?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        upEvent?.post(tap: .cghidEventTap)

        usleep(10000)
    }
    print("Typed: \(text)")
}

func cmdPress(key: String) {
    let src = CGEventSource(stateID: .hidSystemState)

    var modifiers: CGEventFlags = []
    var keyCode: CGKeyCode = 0
    var parts = key.lowercased().split(separator: "+").map(String.init)
    let keyName = parts.removeLast()

    for mod in parts {
        switch mod {
        case "cmd", "command": modifiers.insert(.maskCommand)
        case "ctrl", "control": modifiers.insert(.maskControl)
        case "alt", "option": modifiers.insert(.maskAlternate)
        case "shift": modifiers.insert(.maskShift)
        default: break
        }
    }

    let keyMap: [String: CGKeyCode] = [
        "return": 36, "enter": 36, "tab": 48, "space": 49,
        "delete": 51, "backspace": 51, "escape": 53, "esc": 53,
        "up": 126, "down": 125, "left": 123, "right": 124,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 101,
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3,
        "g": 5, "h": 4, "i": 34, "j": 38, "k": 40, "l": 37,
        "m": 46, "n": 45, "o": 31, "p": 35, "q": 12, "r": 15,
        "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7,
        "y": 16, "z": 6,
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21,
        "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
    ]

    keyCode = keyMap[keyName] ?? 0

    let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
    down?.flags = modifiers
    down?.post(tap: .cghidEventTap)

    let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
    up?.flags = modifiers
    up?.post(tap: .cghidEventTap)

    print("Pressed: \(key)")
}

func cmdListWindows() {
    for (name, pid) in getRunningApps() {
        let app = AXUIElementCreateApplication(pid)
        if let windows = getAttributeValue(app, kAXWindowsAttribute as String) as? [AXUIElement] {
            for win in windows {
                let title = getStringAttribute(win, kAXTitleAttribute as String)
                let pos = getPosition(win)
                let size = getSize(win)
                let posStr = pos.map { "\($0.0),\($0.1)" } ?? "?"
                let sizeStr = size.map { "\($0.0)x\($0.1)" } ?? "?"
                print("\(name) | \(title) | \(posStr) | \(sizeStr)")
            }
        }
    }
}

func cmdListApps() {
    for (name, pid) in getRunningApps() {
        print("\(name) | pid \(pid)")
    }
}

func printUsage() {
    print("""
    cloude-ui — Mac UI automation via Accessibility API

    Commands:
      see [app_name]           Show interactive elements of app (default: frontmost)
      click <id> [app_name]    Click element by ID from 'see' output
      type "text"              Type text into focused field
      press <key>              Press key combo (e.g. cmd+s, ctrl+shift+a, return)
      windows                  List all open windows
      apps                     List running applications

    Examples:
      cloude-ui see                    # Elements of frontmost app
      cloude-ui see "System Settings"  # Elements of System Settings
      cloude-ui click 5                # Click element 5
      cloude-ui type "hello world"     # Type text
      cloude-ui press cmd+s            # Save shortcut
      cloude-ui press return            # Press Enter
    """)
}

let args = CommandLine.arguments
if args.count < 2 {
    printUsage()
    exit(0)
}

switch args[1] {
case "see":
    cmdSee(appName: args.count > 2 ? args[2] : nil)
case "click":
    if args.count < 3 {
        print("Usage: cloude-ui click <element_id> [app_name]")
        exit(1)
    }
    if let id = Int(args[2]) {
        cmdClick(elementId: id, appName: args.count > 3 ? args[3] : nil)
    } else {
        print("ERROR: Invalid element ID '\(args[2])'")
        exit(1)
    }
case "type":
    if args.count < 3 {
        print("Usage: cloude-ui type \"text to type\"")
        exit(1)
    }
    cmdType(text: args[2])
case "press":
    if args.count < 3 {
        print("Usage: cloude-ui press <key> (e.g. cmd+s, return, escape)")
        exit(1)
    }
    cmdPress(key: args[2])
case "windows":
    cmdListWindows()
case "apps":
    cmdListApps()
default:
    print("Unknown command: \(args[1])")
    printUsage()
    exit(1)
}
