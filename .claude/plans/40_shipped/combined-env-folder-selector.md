# Combined Environment + Folder Selector {rectangle.on.rectangle}
<!-- priority: 10 -->
<!-- tags: ui, env -->
<!-- build: 86 -->

> Grouped environment and folder pickers into a single card with auto-open folder picker on env change and disabled state when disconnected.

- Environment and folder pickers grouped into a single rounded card
- Environment row on top, folder row below, separated by a divider
- Both rows stretch full width with chevrons aligned right
- Single `oceanSecondary` background communicates they're related
- Changing environment auto-opens the folder picker sheet (only if env is connected)
- Folder picker disabled (dimmed) when environment connection is not live
- Window tabs (files, git, terminal) disabled when environment is disconnected
