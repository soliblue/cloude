---
title: "Plans Sheet Empty on Device"
description: "Plans sheet loads correctly in Simulator but shows empty on a real device."
created_at: 2026-03-29
tags: ["ui", "agent"]
icon: doc.text.magnifyingglass
build: 120
---


# Plans Sheet Empty on Device {doc.text.magnifyingglass}
## Problem
Opening the plans sheet on a physical iPhone shows no plans, while the same build in Simulator displays them correctly. This is a device-specific bug — the data exists but is not loading or rendering on real hardware.

## Desired Outcome
The plans sheet shows the same content on a real device as it does in Simulator.

## How to Test
1. Build and run on a physical iPhone
2. Open the plans sheet
3. It should show the same plans visible in Simulator
4. All stages (backlog, next, active, testing, done) should populate correctly
