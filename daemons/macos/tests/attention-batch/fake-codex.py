#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys


def send(value):
    print(json.dumps(value), flush=True)


for line in sys.stdin:
    message = json.loads(line)
    method = message.get('method')
    if method == 'initialized':
        continue
    with (Path(os.environ['CODEX_HOME']) / 'rpc.jsonl').open('a') as log:
        log.write(json.dumps({'method': method}) + '\n')
    if method == 'fixture/seed':
        send({'method': 'thread/started', 'params': {'thread': {'id': 'child-thread', 'parentThreadId': 'parent-thread'}}})
        send({'method': 'thread/started', 'params': {'thread': {'id': 'leaf-thread', 'parentThreadId': 'child-thread'}}})
        send({'id': 700, 'method': 'item/permissions/requestApproval', 'params': {'threadId': 'leaf-thread', 'permissions': {'network': {'enabled': True}}}})
        send({'id': 701, 'method': 'item/tool/requestUserInput', 'params': {'threadId': 'parent-thread', 'questions': [{'id': 'fixture', 'question': 'Fixture only'}]}})
    elif method == 'fixture/resolve':
        send({'method': 'serverRequest/resolved', 'params': {'threadId': 'leaf-thread', 'requestId': 700}})
    elif method == 'fixture/complete':
        send({'method': 'turn/completed', 'params': {'threadId': 'parent-thread', 'turn': {'status': 'completed'}}})
    else:
        assert method == 'initialize', method
    send({'id': message['id'], 'result': {}})
