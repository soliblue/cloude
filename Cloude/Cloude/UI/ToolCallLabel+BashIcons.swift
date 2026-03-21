import SwiftUI

let bashIconMap: [String: String] = [
    "ls": "list.bullet",
    "cd": "folder",
    "pwd": "location",
    "mkdir": "folder.badge.plus",
    "rm": "trash",
    "rmdir": "folder.badge.minus",
    "cp": "doc.on.doc",
    "mv": "arrow.right.doc.on.clipboard",
    "touch": "doc.badge.plus",
    "cat": "doc.text",
    "head": "doc.text",
    "tail": "doc.text",
    "less": "doc.text",
    "more": "doc.text",
    "chmod": "lock.shield",
    "chown": "lock.shield",
    "python": "chevron.left.forwardslash.chevron.right",
    "python3": "chevron.left.forwardslash.chevron.right",
    "node": "chevron.left.forwardslash.chevron.right",
    "xcodebuild": "hammer",
    "fastlane": "airplane",
    "make": "hammer",
    "curl": "arrow.down.circle",
    "wget": "arrow.down.circle",
    "grep": "magnifyingglass",
    "rg": "magnifyingglass",
    "ag": "magnifyingglass",
    "find": "folder.badge.questionmark",
    "fd": "folder.badge.questionmark",
    "echo": "text.bubble",
    "printf": "text.bubble",
    "export": "gearshape",
    "env": "gearshape",
    "source": "arrow.right.circle",
    ".": "arrow.right.circle",
    "ssh": "server.rack",
    "scp": "arrow.left.arrow.right",
    "rsync": "arrow.left.arrow.right",
    "tar": "archivebox",
    "zip": "archivebox",
    "unzip": "archivebox",
    "gzip": "archivebox",
    "brew": "mug",
    "cloude": "message.badge.waveform",
    "claude": "brain.head.profile",
    "pytest": "checkmark.diamond",
    "jest": "checkmark.diamond",
    "mocha": "checkmark.diamond",
    "vitest": "checkmark.diamond",
    "eslint": "wand.and.stars",
    "prettier": "wand.and.stars",
    "rubocop": "wand.and.stars",
    "code": "chevron.left.forwardslash.chevron.right",
    "vim": "pencil.and.outline",
    "nvim": "pencil.and.outline",
    "nano": "pencil.and.outline",
    "emacs": "pencil.and.outline",
    "man": "questionmark.circle",
    "help": "questionmark.circle",
    "which": "location.magnifyingglass",
    "whereis": "location.magnifyingglass",
    "type": "location.magnifyingglass",
    "ps": "cpu",
    "top": "cpu",
    "htop": "cpu",
    "kill": "xmark.circle",
    "killall": "xmark.circle",
    "open": "arrow.up.forward.square",
    "pbcopy": "doc.on.clipboard",
    "pbpaste": "doc.on.clipboard",
    "date": "calendar",
    "whoami": "person",
    "sleep": "moon.zzz",
    "clear": "eraser",
    "history": "clock.arrow.circlepath",
    "alias": "link",
    "wc": "number",
    "sort": "arrow.up.arrow.down",
    "uniq": "star",
    "diff": "plus.forwardslash.minus",
    "sed": "text.magnifyingglass",
    "awk": "text.magnifyingglass",
    "tee": "arrow.triangle.branch",
    "xargs": "arrow.right.to.line"
]

let gitSubcommandIcons: [String: String] = [
    "commit": "checkmark.circle",
    "push": "arrow.up.circle",
    "pull": "arrow.down.circle",
    "clone": "square.and.arrow.down",
    "branch": "arrow.triangle.branch",
    "checkout": "arrow.triangle.swap",
    "switch": "arrow.triangle.swap",
    "merge": "arrow.triangle.merge",
    "rebase": "arrow.triangle.capsulepath",
    "status": "questionmark.folder",
    "diff": "plus.forwardslash.minus",
    "log": "clock.arrow.circlepath",
    "stash": "tray.and.arrow.down",
    "fetch": "arrow.down.doc",
    "reset": "arrow.uturn.backward.circle",
    "add": "plus.circle",
    "init": "sparkles",
    "remote": "network"
]

let npmSubcommandIcons: [String: String] = [
    "install": "square.and.arrow.down",
    "i": "square.and.arrow.down",
    "add": "square.and.arrow.down",
    "run": "play",
    "start": "play",
    "test": "checkmark.diamond",
    "build": "hammer",
    "publish": "paperplane",
    "init": "sparkles",
    "uninstall": "trash",
    "remove": "trash",
    "rm": "trash",
    "update": "arrow.up.circle",
    "upgrade": "arrow.up.circle"
]

let cargoSubcommandIcons: [String: String] = [
    "build": "hammer",
    "run": "play",
    "test": "checkmark.diamond",
    "new": "sparkles",
    "init": "sparkles",
    "publish": "paperplane",
    "add": "plus.circle",
    "remove": "minus.circle",
    "update": "arrow.up.circle"
]

let pipSubcommandIcons: [String: String] = [
    "install": "square.and.arrow.down",
    "uninstall": "trash",
    "list": "list.bullet",
    "freeze": "snowflake"
]

let swiftSubcommandIcons: [String: String] = [
    "build": "hammer",
    "run": "play",
    "test": "checkmark.diamond",
    "package": "shippingbox"
]

let dockerSubcommandIcons: [String: String] = [
    "build": "hammer",
    "run": "play",
    "push": "arrow.up.circle",
    "pull": "arrow.down.circle",
    "stop": "stop",
    "ps": "list.bullet",
    "ls": "list.bullet",
    "rm": "trash",
    "rmi": "trash"
]

let kubectlSubcommandIcons: [String: String] = [
    "get": "list.bullet",
    "apply": "checkmark.circle",
    "delete": "trash",
    "describe": "doc.text.magnifyingglass",
    "logs": "text.alignleft",
    "exec": "terminal"
]

