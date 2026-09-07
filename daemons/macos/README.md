# Mac daemon

## Inline Codex review

Codex chat accepts the same optional `reviewTarget` as the Linux daemon: uncommitted changes, a base branch, a commit SHA with optional title, or custom instructions. The daemon validates the target before native requests and rejects it for Claude. It uses official `review/start` with inline delivery after the existing subscription, quota, and provider checks. The standard NDJSON stream, approval replies, interruption, and replay journal also carry reviews.

Review lifecycle events use `reviewing` and `review_complete` status. A final report supplied only in `exitedReviewMode.review` becomes assistant output, and bounded SHA256 state prevents duplicating a report already streamed by Codex. The `codexReview` capability advertises support.

Run `bash daemons/macos/tests/run-codex-review-tests.sh` for fake-process coverage of native protocol ordering, subscription rejection, approvals, interruption, standalone report text, deduplication, and durable journal replay. This test never invokes a real model.
