#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
build="/tmp/remotecc-macos-http-smoke"
port="18766"
token="$(openssl rand -base64 32 | tr -d '\n')"
xcodebuild -project "$root/daemons/macos/macOSDaemon.xcodeproj" -scheme "Cloude Agent" -destination "platform=macOS,arch=arm64" -derivedDataPath "$build" CODE_SIGNING_ALLOWED=NO build >/tmp/remotecc-macos-http-smoke.log
app="$build/Build/Products/Debug/Remote CC Daemon.app/Contents/MacOS/Remote CC Daemon"
fixture="$(mktemp -d /tmp/remotecc-http-fixture.XXXXXX)"
env CLOUDE_DATA="$fixture/state" CLOUDE_PORT="$port" CLOUDE_AUTH_TOKEN="$token" "$app" >/tmp/remotecc-macos-http-smoke-daemon.log 2>&1 &
daemon_pid=$!
trap 'kill "$daemon_pid" 2>/dev/null || true; rm -rf "${fixture:-}" 2>/dev/null || true' EXIT
for _ in {1..50}; do
    if curl -fsS --max-time 20 -H "Authorization: Bearer $token" "http://127.0.0.1:$port/ping" >/dev/null; then break; fi
    sleep 0.2
done
json="$(curl -fsS --max-time 20 -H "Authorization: Bearer $token" "http://127.0.0.1:$port/codex/account")"
[[ "$json" == *'"chatgpt"'* ]]
models="$(curl -fsS --max-time 20 -H "Authorization: Bearer $token" "http://127.0.0.1:$port/codex/models")"
python3 -c 'import json,sys; x=json.load(sys.stdin); assert x.get("models") or x.get("data")' <<< "$models"
session_id="$(python3 -c 'import uuid; print(uuid.uuid4())')"
first="$(curl -fsS --no-buffer --max-time 60 -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -X POST "http://127.0.0.1:$port/sessions/$session_id/chat" --data "{\"path\":\"$fixture\",\"prompt\":\"Remember ALPHA-731. Reply ALPHA-731 only.\",\"provider\":\"codex\",\"permissionMode\":\"standard\",\"model\":\"gpt-5.6-luna\",\"effort\":\"low\"}")"
first_text="$(python3 -c 'import json,sys; print("".join(x.get("event", {}).get("event", {}).get("delta", {}).get("text", "") for x in (json.loads(line) for line in sys.stdin if line)))' <<< "$first")"
[[ "$first_text" == *'ALPHA-731'* ]]
thread_id="$(python3 -c 'import json,sys; lines=[json.loads(x) for x in sys.stdin.read().splitlines() if x]; print(next(x["threadId"] for x in lines if x.get("type")=="session"))' <<< "$first")"
second="$(curl -fsS --no-buffer --max-time 60 -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -X POST "http://127.0.0.1:$port/sessions/$session_id/chat" --data "{\"path\":\"$fixture\",\"prompt\":\"What marker did I ask you to remember? Reply with it only.\",\"provider\":\"codex\",\"existsOnServer\":true,\"model\":\"gpt-5.6-luna\",\"effort\":\"low\"}")"
second_text="$(python3 -c 'import json,sys; print("".join(x.get("event", {}).get("event", {}).get("delta", {}).get("text", "") for x in (json.loads(line) for line in sys.stdin if line)))' <<< "$second")"
[[ "$second_text" == *'ALPHA-731'* ]]
second_thread_id="$(python3 -c 'import json,sys; lines=[json.loads(x) for x in sys.stdin.read().splitlines() if x]; print(next(x["threadId"] for x in lines if x.get("type")=="session"))' <<< "$second")"
[[ "$thread_id" == "$second_thread_id" ]]
fork_id="$(python3 -c 'import uuid; print(uuid.uuid4())')"
fork="$(curl -fsS --max-time 20 -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -X POST "http://127.0.0.1:$port/sessions/$session_id/fork" --data "{\"path\":\"$fixture\",\"newSessionId\":\"$fork_id\"}")"
python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["sessionId"] and x["threadId"] and x["thread"]' <<< "$fork"
fork_text="$(curl -fsS --no-buffer --max-time 60 -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -X POST "http://127.0.0.1:$port/sessions/$fork_id/chat" --data "{\"path\":\"$fixture\",\"prompt\":\"What marker did I ask you to remember? Reply with it only.\",\"provider\":\"codex\",\"existsOnServer\":true,\"model\":\"gpt-5.6-luna\",\"effort\":\"low\"}")"
fork_text="$(python3 -c 'import json,sys; print("".join(x.get("event", {}).get("event", {}).get("delta", {}).get("text", "") for x in (json.loads(line) for line in sys.stdin if line)))' <<< "$fork_text")"
[[ "$fork_text" == *'ALPHA-731'* ]]
thread_history="$(curl -fsS --max-time 20 -H "Authorization: Bearer $token" "http://127.0.0.1:$port/sessions/$session_id/history")"
python3 -c 'import json,sys; x=json.load(sys.stdin)["thread"]; assert x["id"] == sys.argv[1]; assert len(x["turns"]) >= 2' "$thread_id" <<< "$thread_history"
printf "%s\n" "$second" > "$fixture/second.jsonl"
curl -fsS --max-time 20 -H "Authorization: Bearer $token" "http://127.0.0.1:$port/sessions/$session_id/chat/resume?after_seq=3" > "$fixture/resume.jsonl"
python3 -c 'import json,sys; read=lambda p:[json.loads(x) for x in open(p) if x.strip()]; assert [x for x in read(sys.argv[1]) if x["seq"]>3] == read(sys.argv[2])' "$fixture/second.jsonl" "$fixture/resume.jsonl"
kill "$daemon_pid"
wait "$daemon_pid" 2>/dev/null || true
env CLOUDE_DATA="$fixture/state" CLOUDE_PORT="$port" CLOUDE_AUTH_TOKEN="$token" "$app" >/tmp/remotecc-macos-http-smoke-daemon.log 2>&1 &
daemon_pid=$!
for _ in {1..50}; do
    if curl -fsS --max-time 2 -H "Authorization: Bearer $token" "http://127.0.0.1:$port/ping" >/dev/null 2>&1; then break; fi
    sleep 0.2
done
curl -fsS --max-time 20 -H "Authorization: Bearer $token" "http://127.0.0.1:$port/sessions/$session_id/chat/resume?after_seq=3" > "$fixture/restarted.jsonl"
python3 -c 'import json,sys; read=lambda p:[json.loads(x) for x in open(p) if x.strip()]; assert read(sys.argv[1]) == read(sys.argv[2])' "$fixture/resume.jsonl" "$fixture/restarted.jsonl"
for archived_id in "$session_id" "$fork_id"; do
    curl -fsS --max-time 20 -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -X POST "http://127.0.0.1:$port/sessions/$archived_id/archive" --data '{"archived":true}' >/dev/null
done
printf "%s\n" "macOS Codex HTTP smoke passed: context, fork, exact suffix replay and daemon restart"
