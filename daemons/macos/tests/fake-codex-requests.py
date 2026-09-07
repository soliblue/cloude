#!/usr/bin/python3
import json
import os
import sys

os.makedirs(os.environ['CODEX_HOME'], exist_ok=True)
record = os.path.join(os.environ['CODEX_HOME'], 'responses.jsonl')

def emit(value):
    print(json.dumps(value), flush=True)

for line in sys.stdin:
    message = json.loads(line)
    method = message.get('method')
    if not method:
        with open(record, 'a', encoding='utf-8') as file:
            file.write(json.dumps(message) + '\n')
        continue
    if method == 'initialized':
        continue
    if method == 'fixture/requests':
        emit({'id': 7, 'method': 'item/permissions/requestApproval', 'params': {'threadId': 'child-thread', 'permissions': {'network': {'enabled': True}}}})
        emit({'id': '7', 'method': 'item/tool/requestUserInput', 'params': {'threadId': 'child-thread', 'questions': []}})
        emit({'id': 8, 'method': 'item/commandExecution/requestApproval', 'params': {'threadId': 'parent-thread', 'command': 'pwd'}})
    if method == 'fixture/resolved':
        emit({'method': 'serverRequest/resolved', 'params': {'threadId': 'child-thread', 'requestId': '7'}})
    if method == 'fixture/completed':
        emit({'method': 'turn/completed', 'params': {'threadId': 'parent-thread', 'turn': {'id': 'turn', 'status': 'completed'}}})
    emit({'id': message['id'], 'result': {}})
