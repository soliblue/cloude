#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS=(
  run_claude_policy_tests.sh
  run_codex_plugin_handler_tests.sh
  run_codex_handler_tests.sh
  run-codex-fork-retry-tests.sh
  run-codex-client-tests.sh
  run-codex-activity-tests.sh
  run-codex-auth-fence-tests.sh
  run-daemon-lifecycle-tests.sh
  run-codex-attention-tests.sh
  run-codex-attention-batch-tests.sh
  run-codex-requests-tests.sh
  run-codex-control-tests.sh
  run-codex-compaction-tests.sh
  run-codex-journal-tests.sh
  run-codex-event-tests.sh
  run-codex-review-tests.sh
  run-codex-steer-tests.sh
  run-codex-resume-guard-tests.sh
  run-codex-section-tests.sh
  run-codex-shell-tests.sh
  run-codex-terminal-tests.sh
  run-codex-subscription-policy-tests.sh
  run-git-handler-tests.sh
  run-git-worktree-tests.sh
  run-runner-recording-tests.sh
  run-push-delivery-tests.sh
  run-daemon-updater-tests.sh
  run-http-admission-tests.sh
  run-transcription-operation-tests.sh
  run-transcribe-handler-tests.sh
)
for script in "${SCRIPTS[@]}"; do
  "$ROOT/$script"
done
