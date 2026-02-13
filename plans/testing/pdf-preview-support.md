# PDF Preview Support

Add native PDF viewing in file previews using PDFKit.

## Changes
- Added `.pdf` case to `FileContentType` enum
- Created `PDFPreview` view (UIViewRepresentable wrapping PDFKit.PDFView with autoScales)
- Wired PDF into `FilePathPreviewView+Content` (file path pill tap route)
- Wired PDF into `FilePreviewView+Loading` (file browser route)
- Added `isAudio` and `isPDF` computed properties to `FileEntry+Display`
- Bonus: wired audio into file browser route (was missing)

## Test
- Tap a PDF file path in chat — should render with scroll + pinch-to-zoom
- Browse to a PDF in file browser — should render the same way
- Audio files in file browser should now also play (was previously binary placeholder)
