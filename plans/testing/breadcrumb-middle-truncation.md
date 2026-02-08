# Breadcrumb — Middle Truncation for Filenames

Filename in breadcrumb now uses middle truncation to preserve the file extension. e.g. `AutocompleteS….swift` instead of `AutocompleteS…`.

**File**: `Cloude/Cloude/UI/FileViewerBreadcrumb.swift`

**How to test**: Open a file with a long name — the breadcrumb filename should show the start + `…` + `.extension`.
