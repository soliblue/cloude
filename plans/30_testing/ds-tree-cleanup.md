# DS Token Cleanup - Tree Widget & Recording Dot
<!-- build: 116 -->

## Changes
- Tree widget: removed connector lines (vertical + horizontal), removed icon frame, removed icon top padding
- Recording overlay dot: changed from DS.Size.xs to DS.Icon.s
- Deleted dead code: ConnectionStatus component

## Test
- Open any tree widget (e.g. folder structure) — nodes should be indented, no connector lines
- Start a voice recording — pulsing dot should appear larger than before (~14pt base)
