#!/usr/bin/env python3
import json
import sys

def send(value):
    sys.stdout.write(json.dumps(value) + "\n")
    sys.stdout.flush()

for line in sys.stdin:
    message = json.loads(line)
    if message.get("method") == "initialize":
        send({"id": message["id"], "result": {}})
    elif message.get("method") == "trigger":
        send({"method": "thread/started", "params": {"thread": {"id": "child-a", "source": {"subAgent": {"thread_spawn": {"parent_thread_id": "parent-thread"}}}}}})
        send({"method": "item/completed", "params": {"threadId": "parent-thread", "item": {"type": "collabAgentToolCall", "tool": "spawnAgent", "receiverThreadIds": ["child-b"]}}})
        send({"method": "thread/started", "params": {"thread": {"id": "child-c", "parentThreadId": "child-b"}}})
        send({"id": 700, "method": "item/permissions/requestApproval", "params": {"threadId": "child-c", "permissions": {"network": {"enabled": True}}}})
        send({"id": message["id"], "result": {}})
    elif message.get("method") == "finish":
        send({"method": "turn/completed", "params": {"threadId": "child-c", "turn": {"status": "completed"}}})
        send({"id": message["id"], "result": {}})
    elif message.get("method") == "activity":
        send({"method": "item/started", "params": {"threadId": "parent-thread", "item": {"type": "subAgentActivity", "kind": "started", "agentThreadId": "child-d"}}})
        send({"id": 701, "method": "item/permissions/requestApproval", "params": {"threadId": "child-d", "permissions": {"network": {"enabled": True}}}})
        send({"id": message["id"], "result": {}})
    elif "id" in message:
        send({"id": message["id"], "result": {}})
