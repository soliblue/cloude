# Debug Overlay

Floating diagnostic panel for identifying regressions and tracking app health. Toggled from Settings, disabled by default.

**Constraint**: all metric logic lives in `DebugMetrics.swift` + `DebugOverlayView.swift` only. No changes to any other file.

## Current State

Already implemented:
- FPS via CADisplayLink
- OWC/sec (ConnectionManager.objectWillChange fires per second)
- Draggable overlay, minimized/expanded states, Settings toggle

## Metrics to Add

### High Priority

**Hitch stats** (replaces simple drop counter)
- `hitchesPerSec`: frames where interval > 1.5x target (16.6ms at 60Hz, 8.3ms at 120Hz)
- `worstFrameMs`: worst single frame time since session start
- Computed from existing CADisplayLink delta in `recordFrame()`

**OWC enhancements**
- `owcAvg5s`: rolling 5s average (ring buffer of last 5 one-second samples)
- `owcPeak`: peak in last 60s (rolling window, not lifetime)
- Replaces current single-sample OWC

**Memory** (poll every 2s via existing timer)
- `memCurrent`: `phys_footprint` via `task_vm_info` mach call
- `memPeak`: high-water mark since launch
- `memGrowth`: current - value at launch (confirms leak vs normal usage)

**Main-thread stall detector**
- Heartbeat task on background thread pings main every 100ms
- If response takes >100ms = minor stall, >250ms = major stall
- Counters: `stallsMinor`, `stallsMajor`
- Catches typing lag and scroll freezes that FPS misses entirely

### Medium Priority

**CPU usage** (poll every 1s)
- `cpu1s`: smoothed 1s average (raw instant is too noisy)
- `cpu10s`: smoothed 10s average
- Process-level via `host_statistics` or `proc_pid_rusage`

**Thread count**
- `threadCount`: active thread count via `task_threads`
- Catches runaway thread creation from networking/image pipelines

**Thermal state + Low Power Mode**
- `thermalState`: `ProcessInfo.processInfo.thermalState` (.nominal/.fair/.serious/.critical)
- `isLowPowerMode`: `ProcessInfo.processInfo.isLowPowerModeEnabled`
- Context for "it's slow on this device" without it being a code regression

**Memory warnings count**
- `memWarnings`: NotificationCenter observer for `UIApplication.didReceiveMemoryWarningNotification`
- Counter increments, never resets. Frequent warnings = close to being killed by iOS.

### Low Priority (context only)

**App uptime**
- `launchDate = Date()` at init
- Displayed as context for all cumulative counters ("47 hitches over 3m")

## Overlay Panel

Minimized: `FPS | MEM | CPU`

Expanded sections:
- **Render**: fps, hitches/sec, worst frame ms, stalls minor/major
- **State**: OWC/sec (5s avg), OWC peak
- **Memory**: current, peak, growth since launch, warning count
- **System**: CPU 1s/10s, threads, thermal, low power mode
- **Meta**: uptime

## Files
- **Edit**: `Cloude/Services/DebugMetrics.swift`
- **Edit**: `Cloude/UI/DebugOverlayView.swift`
