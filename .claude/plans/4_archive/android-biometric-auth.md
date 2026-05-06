---
title: "Android Biometric Auth"
description: "Lock screen with fingerprint/face unlock."
created_at: 2026-03-28
tags: ["android", "security"]
icon: faceid
build: 120
---
# Android Biometric Auth


## Desired Outcome
Optional biometric lock on app launch. Settings toggle to enable/disable. Prompt on app resume from background.

## iOS Reference Architecture

### Components
- `BiometricAuth.swift` - checks `LAContext().canEvaluatePolicy`, detects biometric type (Face ID / Touch ID) for icon/label
- `CloudeApp+LockScreen.swift` - lock screen overlay shown when app enters foreground with biometric auth enabled
- Auth state stored in `AppStorage`

### Android implementation notes
- `androidx.biometric:biometric` library for `BiometricPrompt`
- Check `BiometricManager.canAuthenticate(BIOMETRIC_STRONG)` for availability
- `BiometricPrompt.PromptInfo.Builder` for prompt configuration
- Settings toggle stored in `SharedPreferences` / `DataStore`
- Show lock overlay in `MainActivity` `onResume` when enabled
- Handle `BiometricPrompt.AuthenticationCallback` for success/error/failure
- Android supports fingerprint, face, and iris - detect and show appropriate label

**Files (iOS reference):** BiometricAuth.swift, CloudeApp+LockScreen.swift
