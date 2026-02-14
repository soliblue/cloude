# Kokoro MLX Fixes

Clean up agent startup for Kokoro TTS with MLX backend.

## Changes
- Condensed verbose startup logging to single-line messages
- Added `disable-library-validation` entitlement for MLX dynamic libs
- Suppress stderr noise from MLX during model/voice loading
- Download retries (3 attempts) + alternative model URL (GitHub mirror)
- Explicit MLX + MLXUtilsLibrary SPM dependencies in Xcode project
- Cleaned up WebSocket server verbose state logging

## Build
32d04b6
