# Combined Environment + Folder Selector
<!-- build: 86 -->

- Environment and folder pickers grouped into a single rounded card
- Environment row on top, folder row below, separated by a divider
- Both rows stretch full width with chevrons aligned right
- Single `oceanSecondary` background communicates they're related
- Changing environment auto-opens the folder picker sheet (only if env is connected)
- Folder picker disabled (dimmed) when environment connection is not live
- Window tabs (files, git, terminal) disabled when environment is disconnected
