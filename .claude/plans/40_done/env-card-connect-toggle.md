# Environment Card Connect Toggle

## Problem
Settings environment card had a text-based Connect/Disconnect button, inconsistent with the toolbar power button.

## Solution
Replaced text button with power icon button matching the toolbar style. Uses accent color when connected, StreamingPulseModifier opacity pulse when connecting, dimmed when disconnected.

## File Changed
- `SettingsView+Environments.swift` - EnvironmentCard top bar
