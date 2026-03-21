# Git Line Stats + Pastel Colors {plus.forwardslash.minus}
<!-- priority: 10 -->
<!-- tags: ui, git, theme -->
<!-- build: 86 -->

> Added per-file line stats to git tab and replaced system green/red with pastel colors app-wide.

## What changed
- Git tab shows +N/-N lines added/removed per file row
- Total +N/-N in the status header bar
- Defined `Color.pastelGreen` (#7AB87A) and `Color.pastelRed` (#B54E5E)
- Replaced system `.green`/`.red` with pastels across all semantic usages (git, connection status, team orbs, copy confirmations, terminal, settings)

## Test
- [ ] Git tab: file rows show green +N and red -N on the right
- [ ] Git tab: header shows total +N/-N before staged/changed counts
- [ ] Git diff view: added/deleted status badges use pastel colors
- [ ] Git diff view: line backgrounds use pastel green/red
- [ ] Connection dot: green when connected, red when error
- [ ] Team orbs: working = pastel green, shutdown = pastel red
- [ ] Copy checkmarks: pastel green flash
- [ ] Colors feel cohesive with orange accent (no orange bleed on red)
