# Deep link routes (v2)

Scheme: `cloude://`

## Windows
| route | action |
|---|---|
| `cloude://window/new` | spawn new window (adds session, focuses it) |
| `cloude://window/close` | close focused window |
| `cloude://window/activate?index=N` | activate Nth window (0-based, ordered by `order`) |

## Focused session
| route | action |
|---|---|
| `cloude://session/endpoint?id=<uuid>` | assign endpoint to focused session |
| `cloude://session/path?value=<abs-path>` | set cwd on focused session |
| `cloude://session/tab?value=chat\|files\|git` | switch SessionView tab |
| `cloude://session/model?value=auto\|opus\|sonnet\|haiku` | set model for focused session |
| `cloude://session/effort?value=default\|low\|medium\|high` | set effort for focused session |

## Chat (focused session)
| route | action |
|---|---|
| `cloude://chat/send?text=<urlencoded>` | adds user message, starts stream |
| `cloude://chat/abort` | sends abort to daemon |

## App surfaces
| route | action |
|---|---|
| `cloude://settings` | present SettingsView sheet over active window |
| `cloude://screenshot` | broadcast capture notification |

## Dev endpoint
Seeded on launch when `CLOUDE_DEV_ENDPOINT_HOST/PORT/TOKEN` are set. Default id is `c10de51d-5151-4551-8551-0000000c10de` (constant from `EndpointActions.seedDev`); override via `CLOUDE_DEV_ENV_ID`.
