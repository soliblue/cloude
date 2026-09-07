#!/usr/bin/env python3
import json
import os
import sys


capture = os.environ.get("CODEX_HOME")
if capture:
    os.makedirs(capture, exist_ok=True)
    with open(os.path.join(capture, "environment.json"), "w", encoding="utf-8") as file:
        json.dump(dict(os.environ), file)
    count_path = os.path.join(capture, "initialize-count")
    try:
        initialize_count = int(open(count_path, encoding="utf-8").read())
    except (FileNotFoundError, ValueError):
        initialize_count = 0
    with open(count_path, "w", encoding="utf-8") as file:
        file.write(str(initialize_count + 1))

for line in sys.stdin:
    message = json.loads(line)
    method = message.get("method")
    if method is None:
        continue
    if method == "initialize":
        response = {"id": message["id"], "result": {"initialized": True}}
    elif method == "initialized":
        continue
    elif method == "serverCollision":
        sys.stdout.write(json.dumps({"id": message["id"], "method": "server/request", "params": {"ok": True}}) + "\n")
        sys.stdout.flush()
        response = {"id": message["id"], "result": {"ok": True}}
    elif method == "turn/start":
        sys.stdout.write(json.dumps({"method": "turn/started", "params": {"threadId": message["params"]["threadId"], "turn": {"id": "pending-turn"}}}) + "\n")
        sys.stdout.flush()
        continue
    elif method == "fixture/notification":
        sys.stdout.write(json.dumps(message["params"]) + "\n")
        sys.stdout.flush()
        response = {"id": message["id"], "result": {}}
    elif method == "account/read":
        if message.get("params", {}).get("fixtureRace"):
            sys.stdout.write(json.dumps({"method": "account/updated", "params": {"authMode": "apikey"}}) + "\n")
        response = {"id": message["id"], "result": {"account": {"type": "chatgpt"}}}
    elif method == "timeout":
        continue
    elif method == "rpcError":
        response = {"id": message["id"], "error": {"message": "fake RPC failure"}}
    elif method == "crash":
        sys.exit(7)
    elif method == "malformed":
        sys.stdout.write("not-json\n")
        sys.stdout.flush()
        continue
    else:
        response = {"id": message["id"], "result": {"method": method}}
    sys.stdout.write(json.dumps(response) + "\n")
    sys.stdout.flush()
