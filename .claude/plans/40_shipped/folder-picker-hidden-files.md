# Folder Picker: Hidden Files Toggle {eye.slash}
<!-- build: 120 -->
<!-- priority: 5 -->
<!-- tags: ui, files -->

> Dotfiles should sort to the bottom with a show/hide toggle in the path row.

## Problem
Hidden files (dotfiles) appear mixed in with regular files in the folder picker, adding noise when navigating to common project folders.

## Desired Outcome
- Dotfiles are sorted to the bottom of the file list, below all regular files
- A toggle icon sits in the top-right of the path row (same row as the current path breadcrumb)
- By default, dotfiles are hidden (not shown at all)
- Tapping the toggle shows them (sorted at the bottom)
- Tapping again hides them
- The toggle state persists within the session

## How to Test
1. Open the folder picker and navigate to a directory with dotfiles (e.g. a project root with `.git`, `.env`, `.gitignore`)
2. By default, dotfiles should not appear in the list
3. Tap the toggle icon in the path row
4. Dotfiles should appear, sorted below all regular files
5. Tap the toggle again — dotfiles should disappear
