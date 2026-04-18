---
title: "Android PDF Preview"
description: "Add PDF rendering to the file preview sheet on Android."
created_at: 2026-04-03
tags: ["android", "files", "ui"]
build: 125
icon: doc.richtext
---
# Android PDF Preview {doc.richtext}


## Context
The file preview currently shows "PDF preview not supported" for PDF files. iOS uses `PDFKit` (`PDFView`) to render PDFs natively. Android needs an equivalent.

## Options
- **Android PdfRenderer** (built-in, API 21+): renders individual pages to Bitmap. No text selection, no scrolling built-in. Would need to build a pager/scroll container.
- **AndroidX PDF Viewer** (if available): Google has been working on a Jetpack PDF library but it may not be stable yet.
- **Third-party**: Libraries like `barteksc/AndroidPdfViewer` wrap MuPDF but add APK size.

## Implementation notes
- Write base64-decoded bytes to a temp file, open with `ParcelFileDescriptor`
- Use `PdfRenderer` to render pages to `Bitmap`, display in a `LazyColumn` or `HorizontalPager`
- Clean up temp file on dismiss
- Consider page-at-a-time rendering for large PDFs (the 10MB passport PDF from testing)
