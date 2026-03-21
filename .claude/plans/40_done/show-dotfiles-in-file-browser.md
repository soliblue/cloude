# Show Dotfiles in File Browser {eye}
<!-- priority: 10 -->
<!-- tags: file-preview, agent -->

> Show dotfiles (.env, .claude, .gitignore) in the file browser by removing the skipsHiddenFiles option.

## Change
Removed `.skipsHiddenFiles` option from `FileService.listDirectory` so dotfiles (`.env`, `.claude`, `.gitignore`, etc.) appear in the file browser tab.

## File Changed
- `Cloude Agent/Services/FileManager.swift` - line 19: `options: [.skipsHiddenFiles]` → `options: []`

## Status
Needs agent rebuild to take effect.
