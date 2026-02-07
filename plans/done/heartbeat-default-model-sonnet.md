# Heartbeat Default Model: Sonnet

## Problem
Automatic heartbeats already use `model: "sonnet"` (HeartbeatService.swift line 98), but manual heartbeats pass `model: nil` which defaults to the best (most expensive) model. Manual heartbeats should also default to Sonnet since heartbeats are background maintenance tasks that don't need Opus.

## Changes

### HeartbeatService.swift
- Change manual heartbeat to also pass `model: "sonnet"` instead of `nil`
- Line 98: `let model = automatic ? "sonnet" : nil` → `let model = "sonnet"`

## Scope
Single line change. Automatic heartbeats already use Sonnet — this just makes manual ones consistent.
