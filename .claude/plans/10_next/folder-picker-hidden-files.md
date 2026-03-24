# Folder Picker: Filter Hidden Files

## Problem
The folder/project picker shows hidden files (dotfiles like `.claude`, `.git`, `.config`, etc.) which clutters the view. Most of the time you don't want to see these.

## Fix
- Hide dotfiles by default in the folder picker
- Add a toggle (top trailing) to show/hide hidden files
- Persist the preference

## Files
- `Cloude/Cloude/UI/FileBrowserView.swift` - add filtering logic and toggle button
