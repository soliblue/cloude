#!/usr/bin/env python3
import json
import os
import sys

root = os.environ['CODEX_HOME']

def send(value):
    print(json.dumps(value), flush=True)

for line in sys.stdin:
    message = json.loads(line)
    method = message.get('method')
    mode = open(os.path.join(root, 'mode')).read()
    if method == 'initialized':
        continue
    if method == 'account/read':
        result = {'account': {'type': 'chatgpt'}}
    elif method == 'config/read':
        result = {'config': {}}
    elif method == 'account/rateLimits/read':
        result = {'rateLimits': {'primary': {'usedPercent': 100 if mode == 'quota' else 5}}}
    elif method in ['thread/start', 'thread/resume']:
        result = {'thread': {'id': 'thread'}, 'modelProvider': 'openai', 'model': 'fixture'}
    elif method == 'turn/start':
        send({'method': 'turn/started', 'params': {'threadId': 'thread', 'turn': {'id': 'turn', 'status': 'inProgress'}}})
        result = {'turn': {'id': 'turn'}}
    elif method == 'turn/steer':
        receipts = json.load(open(os.path.join(root, 'receipts.json')))
        assert any(value['status'] == 'pending' for value in receipts.values())
        with open(os.path.join(root, 'calls'), 'a') as output:
            output.write(json.dumps(message['params']) + '\n')
        if mode == 'ambiguous':
            continue
        if mode == 'write-failure':
            os.rename(os.path.join(root, 'receipts.json'), os.path.join(root, 'saved-pending.json'))
            os.mkdir(os.path.join(root, 'receipts.json'))
        result = {'turnId': 'turn'}
    elif method == 'turn/interrupt':
        send({'method': 'turn/completed', 'params': {'threadId': 'thread', 'turn': {'id': 'turn', 'status': 'interrupted'}}})
        result = {}
    else:
        result = {}
    send({'id': message['id'], 'result': result})
