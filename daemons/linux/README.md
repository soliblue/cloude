# Linux Daemon

Afto's Linux service runs Codex and Claude Code under the server owner's subscription login. It exposes authenticated HTTP routes, live NDJSON, offline replay, files, Git, native approvals and remote notifications.

## Setup

On Ubuntu, run the installer from a downloaded release as your normal user. Do not prefix the installer with sudo; it requests sudo for system directories and services. Linux with systemd, curl, tar, Git, sudo and coreutils is required. Node.js 22 or newer is required; the installer can install checksum-verified Node 22.22.1 on x64 and arm64. Codex CLI 0.153.4 or newer is required and the tested version is installed when needed.

```bash
bash install.sh
export PATH="$HOME/.local/bin:$PATH"
codex login --device-auth
```

Sign in to your existing ChatGPT subscription as the same user named in the service unit. Scan the terminal pairing URL/QR in Afto. The URL keeps the compatible `cloude://pair` scheme and uses HTTPS port 443 through the provisioned tunnel. Install `qrencode` if you want a terminal QR image. No public inbound daemon port is required. Newly downloaded cloudflared binaries must match the SHA256 digest of their official GitHub release asset.

Set `CLOUDE_INSTALL_CLAUDE=1` to install Claude too, then run `claude auth login` as the same user. Set `CLOUDE_INSTALL_WHISPER=1` to install local CPU transcription and its free model download; existing voice models are always retained. Python 3 with venv support is needed for this optional installation.

Set `CLOUDE_TUNNEL=0` for a local-only installation without provisioning. Use an SSH forward or your own authenticated HTTPS/VPN setup, then pair manually with the token stored at `~/.cloude-agent/auth-token`. The default service remains bound to `127.0.0.1:8765`. This option does not stop a previously installed tunnel.

## Updates and removal

Run a newer release's installer as the same user to update. The installer repairs ownership and owner write permissions on legacy code entries, without changing voice model or state ownership. It preserves `~/.cloude-agent`, native Codex/Claude logins, existing tunnel identity, and local voice environments. Cached tunnel credentials are reused without provisioning requests; `CLOUDE_REPROVISION=1` explicitly obtains tunnel configuration again. Finish active tasks before a manual service restart.

Release builds also check for updates every six hours when managed by systemd. Updates require a GitHub SHA256 asset digest and a matching stamped version. Archives are bounded, restricted to regular code files, and staged inside the existing writable install directory. The daemon waits for tasks, terminals and their preflight checks, compaction, scheduled run claims, transcription, approvals and pending control requests to finish. The final activity check, code replacement, cleanup and exit run synchronously without yielding to new requests, then systemd restarts the service. Failed replacement rolls code back. Voice models and state are not replaced. Unsupported archives or environments defer to a manual install. Set `CLOUDE_AUTO_UPDATE=0` in the service to disable automatic updates.

```bash
bash /opt/cloude-agent/scripts/uninstall.sh
```

Uninstall disables and removes only the two matching Afto service units. Installation files, tokens, chat journals, voice models, native agent logins, and remote tunnel registration remain available for reinstall. It never kills processes by port or deletes a user's project.

## Publishing dependencies

A TestFlight binary alone cannot give an older daemon Codex support. Publish the matching Linux release archive under a stable `linux-daemon-vVERSION` tag (three-part versions or the existing four-part calendar format) with asset `cloude-linux-daemon.tar.gz`. The archive must contain `release/`, the exact stamped version, `src/`, `scripts/`, `index.js`, package files and installer. The current iOS onboarding and update flows resolve the published release asset; they must not point users at an old raw-main installer. Update any remaining raw-main distribution separately when merging the release. Verify the published asset before directing a phone at it.

Build locally from the approved release checkout without invoking GitHub Actions:

```bash
cd daemons/linux
npm test
node scripts/package-release.mjs 2026.09.07.1 /tmp/afto-release/cloude-linux-daemon.tar.gz
cd /tmp/afto-release
sha256sum --check cloude-linux-daemon.tar.gz.sha256
```

Replace the example version with the chosen release version, numerically newer than the latest published Linux release. Packaging stamps only the temporary archive, rejects unsupported entries through the updater's own archive parser, writes a checksum sidecar, and refuses to replace an existing output. Verify the GitHub repository and Actions billing policy before pushing a release tag: tags trigger the Linux workflow. Publishing a locally built archive to a draft release avoids needing a CI packaging run, but tag-trigger behavior still must be handled explicitly. Publish only after its GitHub asset digest equals the local SHA256 and the tag identifies the approved source commit. The workflow applies the same tag, archive, and digest checks and keeps a new release draft until verification; it refuses to replace a public release.

The existing production service must be upgraded once to acquire these capabilities and the safe updater; its old updater cannot reliably rename the root-owned `/opt` parent. Provisioning/APNs must also be deployed and configured before notification delivery works. These are separate release steps and were not performed by the isolated daemon tests.

## Security

**Your server is a computer exposed to the entire internet.** Without hardening, anyone can scan your IP and access services directly, bypassing Cloudflare.

### The problem

```
Safe path:     phone -> cloude-medina.soli.blue -> Cloudflare edge -> tunnel -> localhost:8765
Unsafe path:   attacker -> 178.x.x.x:8765 -> direct access, no protection
```

Cloudflare Tunnel creates a reverse connection from your server to Cloudflare's edge. Traffic through the domain gets DDoS protection, WAF, rate limiting. But if your ports are open to the world, attackers skip all of that by hitting the IP directly.

### The fix

Run the hardening script:

```bash
sudo ./scripts/harden-firewall.sh
```

This does three things:

1. **SSH**: Disables password auth. Key-only access. Brute force becomes impractical.
2. **Ports 80/443**: Only accepts connections from [Cloudflare's IP ranges](https://www.cloudflare.com/ips/). Everyone else gets dropped.
3. **Port 8765** (daemon): Only accepts connections from localhost. The Cloudflare Tunnel connects internally, so external access is unnecessary.

After hardening, the only way to reach your server is through Cloudflare (for web/WebSocket) or with your SSH key (for admin). The raw IP becomes a dead end.

### Verify

```bash
# Check firewall
sudo ufw status verbose

# Check SSH config
sudo sshd -T | grep passwordauthentication
# should print: passwordauthentication no

# Check daemon is accessible locally
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8765/ping
# should print: 401

# Check authenticated ping
curl -s -H "Authorization: Bearer $(cat ~/.cloude-agent/auth-token)" http://127.0.0.1:8765/ping
# should print: {"ok":true,"serverAt":...}
```

### Updating Cloudflare IPs

Cloudflare publishes their IP ranges at https://www.cloudflare.com/ips/. If they add new ranges, re-run the hardening script. It fetches the latest list automatically.

## Codex subscriptions

The daemon runs the official `codex app-server` protocol over local stdio. Install Codex, then run `codex login --device-auth` as the same Linux user that runs the daemon and sign in with your existing ChatGPT subscription. API key accounts are rejected before starting turns. Claude remains available when its CLI is installed and authenticated; set `CLOUDE_INSTALL_CLAUDE=1` when running the installer to install both CLIs.

No model gateway, token purchase, or separate inference service is needed. Model availability and reasoning levels come directly from your signed-in Codex account. `CLOUDE_CODEX_BIN` can select an existing Codex executable; `CODEX_HOME` can select its existing account/configuration directory.

The installer binds the daemon to localhost for Cloudflare Tunnel. For a private LAN or VPN deployment, choose an appropriate `CLOUDE_HOST` and keep bearer authentication enabled.

## Codex routes

All routes require the existing bearer token.

| Method | Route | Body or result |
| --- | --- | --- |
| GET | `/codex/models` | Official `model/list` result with supported reasoning efforts |
| GET | `/codex/account` | Subscription account status |
| GET | `/codex/limits` | Account usage windows |
| GET | `/codex/skills` | Official installed skills, with `path` query for workspace discovery |
| GET | `/codex/modes` | Native Plan/default collaboration presets |
| GET/POST | `/codex/projects` | List or register native projects with name and roots |
| GET | `/codex/threads` | Thread list; optional `path`, `search`, `cursor`, `archived`; `refresh=true` scans disk instead of using the state database |
| POST | `/sessions/:id/chat` | Existing chat fields plus `provider: "codex"`; optional `threadId` imports an existing Codex thread |
| GET | `/sessions/:id/chat/resume` | Reconnect using `after_seq`; complete current-turn history survives daemon restart |
| POST | `/sessions/:id/chat/steer` | `{ "prompt": "...", "requestId": "UUID" }` steers the active turn; requestId is optional for older clients |
| POST | `/sessions/:id/chat/abort` | Interrupts the active turn |
| GET | `/sessions/:id/chat/requests` | Recover pending approval and user-input requests |
| POST | `/sessions/:id/chat/respond` | `{ "requestId": "...", "result": { "decision": "accept" } }`; use `decline` to reject; question replies use official `answers` structure |
| GET | `/sessions/:id/history` | Official thread history including tools and agent items |
| POST | `/sessions/:id/fork` | `{ "newSessionId": "..." }`; returns the new session and thread IDs |
| POST | `/sessions/:id/name` | Set the native thread name |
| GET/POST/DELETE | `/sessions/:id/goal` | Read, update, or clear native goal state; objective, status, optional token budget |
| POST | `/sessions/:id/import` | Bind an existing native thread and return its full history |
| POST | `/sessions/:id/archive` | `{ "archived": true }` or `false` |

History responses include an ETag. Send `If-None-Match` to receive an empty 304 when the complete native snapshot is unchanged; this avoids repeated phone decoding during visible polling.

The NDJSON stream retains the existing `{ seq, sessionId, event }` contract. Text, reasoning, commands, edits, web searches, MCP calls, and agent calls use the existing chat renderer. Known normalized notifications are sent once, without a duplicate raw payload. Unknown methods and `turn/started` retain the `{ codex: { method, params } }` envelope. Existing journals keep their original sequence numbers. Approval and question requests use `{ type: "request", requestId, method, params }`; successful replies emit `request_resolved`.

The default Codex permission mode uses workspace-write with explicit approvals. Plan mode uses read-only. Only an explicit `bypassPermissions` selection grants unrestricted access. Subscription authentication is required regardless of permission mode.

Steering messages are bounded to 32768 characters. Reuse the same UUID when retrying a message. A durable receipt records only its hash and delivery status: accepted retries return the same `{ok:true}` response, changed content or uncertain delivery returns 409 without another native call. Receipts stay with the session state across new turns and daemon restarts; there is no unsafe expiry that could deliver an old message into a later turn. Clients without request IDs cannot deduplicate a lost acknowledgement.

Stop applies as soon as the native turn ID arrives, including before the start acknowledgement, and sends one interrupt per turn. Start acknowledgements stay pending until their response, observed turn completion, task closure, or app-server disconnect. Closing the phone stream does not cancel the turn.

Run `npm test` for protocol, replay, request routing, and subscription checks. Protocol reference: [Codex App Server](https://learn.chatgpt.com/docs/app-server).

Skill and file selections can accompany chat requests as `skills: [{ name, path }]` and `mentions: [{ name, path }]`. Plan permission mode also selects Codex's native Plan collaboration mode. Goals use native persisted state; these endpoints do not implement a separate scheduler.

Provisioned endpoints forward `PUT /push/device` registrations and completed, failed, and approval-needed alerts to the existing provisioning service. Pending deliveries persist locally, retry after restart, and use stable event IDs. APNs must be configured on that service; a pending registration alone does not establish push delivery.

## Subscription guardrails

Before every Codex turn, the daemon verifies ChatGPT authentication, effective project configuration, the native OpenAI provider and available subscription quota. Account authentication is checked again after thread setup, and steering rechecks the account, project configuration and quota. Native account-change notifications invalidate older account reads; non-ChatGPT authentication blocks inference and approval replies and stops managed model turns without logging out the shared host account. Custom inference URLs or provider credentials are rejected. Exhausted or unavailable quota stops new turns rather than switching to purchased credits. No reset, credit purchase, or capacity purchase API is called.

Claude runs require a Claude.ai subscription with no API-key source. The daemon checks both CLI authentication status and user, canonical workspace ancestor, filesystem-root and managed settings fragments for credential helpers or paid-provider overrides because a Claude.ai login can coexist with an API key. API credential and cloud-provider environment variables are excluded from spawned processes. Automatic Claude task names derive from the transcript without an extra model call.

## Real subscription HTTP checks

The reusable end-to-end check deliberately consumes a small amount of existing Codex subscription quota. Run it only against a disposable authenticated daemon and workspace. It creates temporary native test threads, verifies actual model behavior, and never installs or deploys a daemon.

Create `proof.txt` in the disposable workspace containing `AFTO_REMOTE_LINUX_APPROVAL_OK`. For the optional native skill check, create `.agents/skills/afto-proof/SKILL.md` with name `afto-proof`, a description, and the instruction `Reply with exactly SKILL_TRANSPORT_OK. Do not run tools or modify files.`

```bash
node scripts/verify-codex-http.mjs \
  --url http://127.0.0.1:18768 \
  --token-file /tmp/afto-medina-e2e-token \
  --path /absolute/disposable/workspace \
  --report /tmp/afto-http-report.json \
  --model gpt-5.6-luna \
  --skill-path /absolute/disposable/workspace/.agents/skills/afto-proof/SKILL.md
```

The first phase verifies repeated turns, native thread identity, forked context, Plan/default switching, skill input, explicit approval/reply, live reconnect without duplicate sequence numbers, interruption, and recovery with another turn. The report contains replay evidence and a test identifier; it contains no authentication token.

Stop and restart only that disposable daemon while preserving its state directory, then run the same command with `--phase replay` added. It verifies byte-equivalent journal events after restart and asks the same native thread to recall the original random identifier. This phase archives the native test thread after verification.

Verified against the real Medina Linux host with Node 22.22.1 and Codex CLI 0.153.4: all listed HTTP checks passed, including explicit approval, live reconnect, restart replay and retained model context. Unit and HTTP regression suites also pass locally and on Linux. The installed production daemon was not changed for these checks.

Installer/updater fixtures run without real sudo, services, downloads or provisioning. They cover repeated installation, retained credentials/history/voice, removal ownership, busy update deferral, archive validation and rollback. Real Linux verification also confirmed ETag 304 and reduced thread listing from roughly eight seconds to under one second on the test host.

A malformed push queue is preserved as a private `push-queue.json.corrupt-*` file and recovery starts with an empty queue. Restored entries must match the supported notification/device routes and payloads before delivery. If quarantine cannot complete, the original file remains untouched and new registrations are not acknowledged as durable.

### Git worktree tasks

`GET /sessions/:id/git/branches?path=...` lists local branches and the repository default branch. `GET /sessions/:id/git/worktrees?path=...` lists worktree paths, branches, HEADs, main-worktree status, and lock/prune flags. These endpoints use modern Git's NUL-delimited worktree porcelain protocol, tested with Git 2.43 on Ubuntu.

`POST /sessions/:id/git/worktrees` accepts `{path, branch, baseRef?, requestId?}` and returns `{path, branch, head}`. The branch must be new. The base defaults to HEAD and accepts an existing named ref or commit hash. A new private directory is created under `CLOUDE_DATA/worktrees`; source files, staging, and checkout remain unchanged. Git checkout hooks are disabled for this operation. There is no deletion endpoint.

Clients should generate one UUID `requestId` and retain it across retries of the same request. The daemon persists the source repository, branch, requested base ref, and resolved starting commit before creation. Matching retries return the verified existing worktree, including after daemon restart. Reusing an ID for different inputs or creating an already-existing branch returns 409. Invalid refs and missing commits return 400. Errors use `{error: string}`. Request metadata and worktrees must be preserved across upgrades.

Every HTTP response advertises `X-Daemon-Capabilities: codex,gitMutations,gitWorktrees,codexPlugins,codexCompaction,codexReview`; `/ping` reports the same capability identifiers.

### Subscription sign-in from the phone

Authenticated `GET /codex/login` returns the current in-memory device-code sign-in state. Explicit `POST /codex/login` with an empty body, `{}`, or `{type:"chatgptDeviceCode"}` starts the official Codex ChatGPT device-code flow; repeated calls share the pending attempt. Other login types and credential fields are rejected. The pending result contains `loginId`, `userCode`, and an HTTPS `verificationUrl` on `auth.openai.com`. Open that URL and enter the code to authorize the host with your existing subscription.

Poll GET while the sign-in screen is visible. State `status` is `idle`, `pending`, `completed`, `failed`, or `canceled`; terminal states omit the code and URL. `DELETE /codex/login` cancels only the pending login attempt, never the signed-in account. Cancellation failure remains pending with a safe `error` message so it can be retried. Native start/cancel failures return 502; invalid input returns 400. `/codex/account` remains the separate source of current account information. Daemon/app-server disconnection invalidates pending codes; restart the explicit sign-in flow when needed. Credentials remain managed by Codex on the host.

### Plugins, apps, and MCP discovery

`GET /codex/plugins?path=...` returns Codex's raw `plugin/list` catalog; `installed=true` uses `plugin/installed`. Catalog `forceRefetch=true` is optional. `GET /codex/plugin` reads one plugin using `pluginName` and exactly one `marketplacePath` or `remoteMarketplaceName`. Local marketplace paths must be absolute or start with `~/`.

Explicit `POST /codex/plugin` accepts the same identity plus optional `installAttemptId` and invokes `plugin/install`. The attempt ID correlates native events; it is not a promise of native idempotency. Explicit `DELETE /codex/plugin` accepts `{pluginId}` and invokes `plugin/uninstall`. Native `appsNeedingAuth` and `authPolicy` are returned unchanged. No automatic installation, reconciliation, OAuth, or tool calls run from these routes.

`GET /codex/apps` uses `app/list` with optional `cursor`, `limit` (1 to 100), `threadId`, and `forceRefetch`. `installed=true` uses `app/installed` with optional `threadId` and `forceRefresh`; installed results are not paginated. `POST /codex/apps/read` accepts 1 to 100 `appIds`, optional `includeTools` boolean, and optional `threadId`.

`GET /codex/mcp` returns read-only `mcpServerStatus/list` with `toolsAndAuthOnly` detail and optional `threadId`, `cursor`, and `limit`. Pagination cursors and response schemas pass through unchanged. Invalid or unknown inputs return 400. Native failures return 502 with an operation-specific message and common credential forms redacted. These routes advertise the `codexPlugins` capability.

### Explicit context compaction

`POST /sessions/:id/compact` accepts an empty body and compacts an existing mapped Codex thread through `thread/compact/start`. It verifies the saved thread, ChatGPT authentication, subscription capacity, project configuration, and the resumed OpenAI provider first. Active turns return 409; new turns are also blocked while manual compaction is pending. There is no API-key fallback. Duplicate pending requests return the same operation.

`GET /sessions/:id/compact` returns `{status, threadId, error?, contextTokens?, contextWindow?, usageAt?, completedAt?}`. Status is `idle`, `pending`, `completed`, or `failed`. POST returns 202 while pending, or 200 if completion arrived before the native acknowledgment. Missing mappings return 404, unsupported input 400, subscription/provider rejection 403, and native failures 502. Usage comes only from native token-usage notifications; timestamps use milliseconds since the Unix epoch. Later normal turns keep the recorded usage fresh.

Compaction state is in memory. Disconnecting the app-server marks pending work failed; daemon restart returns idle and clients should refresh native task history instead of polling indefinitely. Native context-compaction turn notifications determine completion. This feature advertises `codexCompaction`.

Thread-scoped app and MCP discovery can restore an unloaded saved thread after daemon restart: only an exact missing-thread error triggers metadata verification, `thread/resume` without turn execution or configuration overrides, and one retry of the original read. Unknown threads and unrelated errors remain errors; discovery never silently switches to host defaults.

### Inline code review

Codex chat requests may include `reviewTarget`: `{type:"uncommittedChanges"}`, `{type:"baseBranch",branch}`, `{type:"commit",sha,title?}`, or `{type:"custom",instructions}`. Review targets are validated before any native request and rejected for Claude. The normal path, prompt/action label, session, model, and permission fields still apply to thread setup. The daemon uses `review/start` with `delivery:"inline"` in place of `turn/start`, after the same subscription, quota, and provider checks.

Reviews use the existing NDJSON chat connection, approval requests, interruption, and durable replay journal. Status envelopes use `reviewing` and `review_complete`; final `exitedReviewMode.review` text becomes assistant output when Codex did not already send matching text. Deduplication uses bounded hash state instead of retaining another copy of the transcript. There is no detached review endpoint. Clients should persist the typed review target with their local user message so retrying remains a review. This feature advertises `codexReview`.

### Direct task commands

Codex chat requests may include `shellCommand`, a nonempty string up to 16384 characters. Commands cannot include images, skills, mentions, or a review target. This action uses official `thread/shellCommand` on the saved or newly created task, preserving shell quoting, pipes, and redirects. It runs with full access outside the task sandbox, so clients must present it as an explicit manual command action. The native default timeout is one hour. This feature advertises `codexShell`.

Commands make no model inference request. ChatGPT account and provider checks still apply, but exhausted subscription quota does not prevent manual commands and the daemon does not request quota for this action. The normal task stream carries command output, completion, and interruption. The immediate native acknowledgement is empty; the daemon adopts the turn ID from `turn/started`, including when cancellation arrives first. Clients must preserve the typed command for retries and must not send it through conversational steering.

### Recovery checks

`node --test test/Codex.test.js test/Subscription.test.js` exercises initialization rejection and timeout recovery, stale process callbacks, transport write failures, and failed journal writes. Output is recorded before broadcast. A storage failure terminates only its task and attempts to interrupt that task; the error advises checking host storage and task status. A failed final journal write reports one failed completion. Reported malformed quota windows block inference rather than silently ignoring a limit.

The isolated Linux native command smoke used a new disposable thread with `pwd`, then `sleep 2; pwd` interrupted by its observed turn ID. Both returned immediate empty acknowledgements, normal command events, and completed/interrupted turn status without invoking a model. No installed service or account was changed.

### Host sections

`GET /codex/sections?cursor=...&limit=50` lists native host sections. `POST /codex/sections` accepts `{name,appearance?}` and returns `{section}`. Names are limited to 120 characters; optional appearance contains `color` and `icon`. `POST /codex/sections/:id/update` accepts the same fields. Omitting appearance preserves it, while null clears it. `DELETE /codex/sections/:id` removes a section and leaves its tasks unsectioned. This feature advertises `codexSections`.

`POST /sessions/:id/section` accepts `{sectionId,beforeThreadId?}`. A null sectionId removes membership; an omitted or null beforeThreadId appends. Session IDs resolve to their saved native task IDs, while beforeThreadId is a native task ID. `GET /codex/sections/:id/threads` returns tasks in native section order with cursor pagination. The general `GET /codex/threads` also accepts sectionId or unsectioned=true; omitted filters include every section. Unsectioned tasks use updated-time ordering. Section and unsectioned filters include all native task source kinds, including helpers moved into a section; the general unfiltered history keeps Codex's default interactive-task filter. Page limits are 1 to 100.

The official `threadSection/list`, `threadSection/create`, `threadSection/update`, `threadSection/delete`, and `thread/section/move` APIs own persistence. Afto does not create a second sections database, invoke inference, or retry creation after an uncertain response. Clients should refresh the catalog after an uncertain create result and after visible mutations. Native section notifications are not available in the current schema.

The disposable Linux verification created and renamed a section, moved a test task into it, restarted only its separate app-server client, verified persisted membership, unsectioned and re-added the task, then deleted the section and verified the task remained. It made no model calls and changed no existing user section. Fake route tests cover authentication, exact RPC mapping, appearance preservation/clearing, native task mapping, pagination, invalid payloads, and safe errors without automatic retries.

Approval requests are captured by the shared Codex client before a task is opened on the phone. Imported helper tasks use the same `/sessions/:id/chat/requests` and `/sessions/:id/chat/respond` routes even without a local runner. Visible imported tasks should poll the request snapshot alongside history. Request IDs are opaque and scoped to the app-server process generation; responses are accepted only for the exact mapped native task, preserve the native wire ID type, and become stale after resolution or disconnect. Requests remain in memory while the native process is alive; disconnected processes cannot accept their old approvals. No decision is made automatically.

`POST /sessions/:id/chat/abort` also supports imported Codex tasks without a local runner. The daemon reads the saved native task, verifies its identity and active status, and interrupts only its latest in-progress turn. It never resumes or starts a task to stop it. A successful request returns `{ok:true,aborted:true,threadId,turnId}`; idle or unmapped tasks return aborted=false. The phone must continue polling status until the native task actually stops. Imported-task steering remains unavailable; the existing steer route only acts on a locally managed running turn.

Helper attention is routed to the nearest task with a local runner using native parent metadata, completed spawn-agent relationships, and modern subAgentActivity started items. Verified thread reads also rebuild these links from metadata and history; native parent metadata takes precedence over activity-derived links. One attention push targets that parent's existing phone session, while its journal emits `{type:"agent_attention",threadId,requestId,pending}`. These notices open the helper task; they are never approval cards for the parent. Resolution, disconnection, or finishing the parent turn clears queued notices. `/sessions/:id/chat/requests` includes the full `agentAttention:[{threadId,requestId}]` snapshot for reconnect and idle-parent recovery. Push-queue storage failures defer delivery instead of interrupting agent streams, and canceled notices are persisted when storage recovers.

Task lifecycle safeguards reject malformed archive flags and refuse to archive or fork active native tasks, including activity reached through another local session. Imports and forks reserve their target session until the native response is validated and saved; concurrent starts or mapping changes return 409. Session lookup is case-insensitive, matching journal identity. External close, archive, or deletion notifications clear pending approvals and finish a live stream instead of leaving its heartbeat running. An omitted reasoning-effort override preserves the value returned by native thread resume. Afto still exposes archival rather than permanent native thread deletion.

### Interactive terminal

`codexTerminal` enables authenticated, task-scoped PTYs backed by native Codex `command/exec`. These commands do not invoke a model or read quota. The endpoint must use its ChatGPT login and built-in provider. Opening a terminal requires explicit `fullAccess:true`; it runs the host's executable absolute `$SHELL -i`, or `/bin/sh -i`, with trusted `TERM=xterm-256color` and `COLORTERM=truecolor` overrides.

- `POST /sessions/:id/terminals`: `{requestId:UUID,path:absolute,fullAccess:true,cols?:80,rows?:24}` returns 202. Retrying the same request ID and arguments returns the existing terminal; conflicting arguments return 409.
- `GET /sessions/:id/terminals`: `{terminals:[...]}`, scoped to this task.
- `GET /sessions/:id/terminals/:terminalId/stream?after_seq=-1`: NDJSON `terminal_state` and `terminal_output` events with increasing `seq`. After replay, a non-sequenced `terminal_ready` snapshot marks the live boundary, including quiet or already-ended terminals. Enable input and renderer-generated replies only after this marker. Output contains `deltaBase64`, `stream`, and `capReached`. Preserve the decoded bytes for a VT terminal renderer.
- `POST /sessions/:id/terminals/:terminalId/input`: `{writerId:UUID,sequence:Int,deltaBase64?,closeStdin?}`. At most 64 KiB per write. Each writer starts at sequence zero and increments by one. Writes serialize; the latest identical sequence reuses its original outcome, including uncertain failures. Older or out-of-order sequences return 409. Keep writer identity and sequence across phone reconnects; never retry ambiguous input under a new sequence.
- `POST /sessions/:id/terminals/:terminalId/resize`: `{cols,rows}`, both integers 1 through 1000. Emits a state event with the new dimensions.
- `DELETE /sessions/:id/terminals/:terminalId`: explicitly terminates the native process. Wait for its streamed final state.

Snapshots include `terminalId`, `sessionId`, `path`, `status` (`running`, `exited`, `failed`), optional `exitCode`/`error`, `lastSeq`, `createdAt` in epoch milliseconds, and `cols`/`rows`. Native output has no capture cap or execution timeout. The daemon retains 1 MiB of replay per terminal, supports four live terminals across the host, and keeps completed entries ten minutes. It retains the latest sequence, input hash and outcome for up to 64 writer identities per terminal, with no lifetime write-count limit. A cursor older than available replay receives `terminal_gap` with `firstSeq` and `requestedAfterSeq`; reset the renderer and show an explicit incomplete-history notice before applying the retained suffix. Do not send unsolicited input to redraw the screen.

Closing the phone connection keeps its terminal running. A daemon/app-server restart ends these connection-owned processes; terminal IDs and replay do not survive that restart. Remote terminals never reuse another task's IDs. No shell daemon, SSH server, cloud service, or model call is created for this feature.

### Scheduled agents

`agentSchedules` provides daemon-owned Codex schedules. The installed native app-server has no scheduling API. Every run creates a fresh task and uses the existing ChatGPT subscription, provider, capacity, permission and journal checks. Scheduled tasks support `default` and `plan` permissions; no API keys, paid credits, full-access mode or automatic approval are added.

The Linux daemon starts scheduling only after `/usr/bin/flock` explicitly confirms exclusive ownership of its private schedule directory. Install Ubuntu's `util-linux` package if unavailable. Losing the lock pauses dispatch. The `agentSchedules` capability advertises the API; `GET /schedules` reports whether this endpoint currently owns the lock and can dispatch. Read-only inventory stays available; mutations return 503 until ownership and storage are healthy. Invalid state is preserved and scheduling pauses.

- `GET /schedules` returns `{schedules,available,error?}`. `GET /schedules/:id` returns one snapshot.
- `POST /schedules` accepts `{requestId:UUID,name,enabled?:false,originSessionId:UUID,task,schedule}`. Task fields are `{provider:"codex",path:absolute,prompt,model?,effort?,permissionMode?:"default"}`. Creating or reading a disabled schedule does not run an agent.
- Calendar cadence is `{kind:"calendar",time:"HH:mm",timeZone:IANA,daysOfWeek:[1..7]}` with Monday equal to 1. Use all seven days for daily, 1 through 5 for weekdays, or one day for weekly. Interval cadence is `{kind:"interval",minutes:15..10080}`.
- `POST /schedules/:id/update` accepts the current integer `revision` and changed fields. Task/cadence replacements are complete objects. A stale revision returns 409.
- `DELETE /schedules/:id` accepts `{revision}` and rejects an active run. Disabling cancels future occurrences and leaves the current run alone.
- `POST /schedules/:id/run` accepts `{requestId:UUID}` and explicitly runs even a disabled schedule. Retrying that request returns its original run; another active run returns 409.
- `GET /schedules/:id/runs?limit=25&cursor=RUN_UUID` returns `{runs,nextCursor?}`, newest first. Each run exposes its fresh `sessionId`, eventual native `threadId`, and `originSessionId`. Existing task history, approval and stop routes apply to that run. Scheduled attention and completion pushes carry `scheduleId` and `runId`, with `sessionId` identifying the saved origin endpoint. Clients open the schedule rather than marking the origin chat completed.

Snapshots expose `id`, `name`, `enabled`, `originSessionId`, `task`, `schedule`, integer `revision`, `createdAt`, `updatedAt`, nullable `nextRunAt`, `activeRun` and `lastRun`. Run statuses are `starting`, `running`, `waiting`, `completed`, `failed`, `interrupted`, and `skipped`; timestamps are epoch milliseconds. Public run payloads contain task identities, status, timestamps and errors; claim filenames and retry bookkeeping stay private. Recent 100 runs per schedule and any active run stay in inventory; native task histories remain available separately. The 100-schedule limit counts active definitions; deletion removes the saved prompt and path while retaining a minimal creation-retry tombstone. Manual request claims remain durable after inventory retention.

Dispatch checks every 15 seconds, claims each occurrence durably before starting, and allows up to 60 seconds of timer delay. A storage write failure after agent start preserves its active claim and pauses further dispatch, preventing overlap. An unavailable endpoint skips past occurrences without catch-up. Startup skips all overdue times and marks unfinished claims interrupted, never blindly retrying a model call. A previous run waiting for approval blocks overlap; the next occurrence is recorded as skipped. A missing local clock time during spring DST is skipped; a repeated autumn time runs once at its earlier occurrence. Intervals follow a fixed UTC cadence anchored when created or enabled. Changing cadence or re-enabling computes a new future occurrence. Saving unchanged timing, including a name or prompt edit, preserves the existing interval anchor.

Tests inject clocks, lock ownership and fake runners; they do not execute scheduled inference. Custom server wrappers must call `agentSchedules.start()` explicitly if scheduling is intended.
