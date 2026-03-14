# Add Light Theme Artists
<!-- build: 86 -->

Added 6 new light themes to balance the dark-heavy theme picker (was 2 light vs 11 dark, now 8 vs 11).

## Changes
- **Morisot** - Mauve/lilac palette. Soft lavender background, purple-tinged surfaces.
- **Sorolla** - Mediterranean blue-white. Bright white with cool blue accents.
- **Cézanne** - Warm Provence stone. Linen with sage/sand tones.
- **Saffron** - Warm golden yellow. Rich cream with golden amber surfaces.
- **Celadon** - Pale jade green. The classic ceramic glaze color.
- **Wedgwood** - Actual blue background. The iconic English pottery blue.

## Files
- `Cloude/Cloude/Utilities/Theme.swift` - Added 6 enum cases, colorScheme entries, and palettes

## Test
- Open theme picker in Settings
- All 6 new themes should appear between Turner and Hokusai
- Saffron should feel distinctly yellow, Celadon distinctly green, Wedgwood distinctly blue
- Text should be readable on all themes
