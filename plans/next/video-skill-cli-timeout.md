# Video Skill CLI Timeout / Crash

## Problem
When running the video generation skill (`create.py`), the Claude Code CLI times out or crashes before the script finishes. Sora video generation takes 1-5 minutes per batch, and the CLI connection drops during that wait. The videos still generate server-side, but the agent loses track of the process and can't report results back.

## Current Workaround
- `download.py` exists to recover videos after a timeout
- SKILL.md documents the issue under "Known Limitations" and "Pre-flight checklist"
- But the agent doesn't automatically recover — it just dies mid-generation

## Desired Behavior
The agent should:
1. Submit the Sora batch and confirm submission succeeded
2. Survive the long wait (or run the generation in the background)
3. Report back with results when videos are ready
4. If the CLI does timeout, gracefully recover using `download.py` on the next turn

## Possible Approaches
- Run `create.py` in the background (Bash `run_in_background`) and poll with `download.py`
- Split `create.py` into submit + poll steps so submission is fast and polling can be retried
- Increase CLI timeout for video generation commands
- Add a wrapper that handles the long-running process and writes status to a file

## Notes
- The Sora jobs are submitted server-side immediately — even if CLI drops, videos generate
- `download.py` already handles recovery, just needs to be wired into the workflow
- Batch mode submits all jobs at once, so submission itself is fast — it's the polling/waiting that times out
