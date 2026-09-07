#!/usr/bin/env python3
import json
import os
import sys

root = os.environ['CODEX_HOME']
mode = open(os.path.join(root, 'mode')).read()
reads = 0

def send(value):
    print(json.dumps(value), flush=True)

def foreign():
    send({'method': 'turn/started', 'params': {'threadId': 'thread', 'turn': {'id': 'foreign', 'status': 'inProgress'}}})
    send({'method': 'item/agentMessage/delta', 'params': {'threadId': 'thread', 'turnId': 'foreign', 'itemId': 'foreign-item', 'delta': 'FOREIGN CONTENT'}})

for line in sys.stdin:
    message = json.loads(line)
    method = message.get('method')
    with open(os.path.join(root, 'calls'), 'a') as output:
        output.write(json.dumps(message) + '\n')
    if method == 'initialized':
        continue
    result = {}
    if method == 'fixture/activate':
        foreign()
    elif method == 'account/read':
        reads += 1
        if mode == 'during-auth' and reads == 2:
            foreign()
        result = {'account': {'type': 'chatgpt'}}
    elif method == 'config/read':
        result = {'config': {}}
    elif method == 'account/rateLimits/read':
        result = {'rateLimits': {'primary': {'usedPercent': 5}}}
    elif method == 'thread/resume':
        if mode == 'during-resume':
            foreign()
        if mode == 'closed':
            send({'method': 'thread/closed', 'params': {'threadId': 'thread'}})
        result = {'thread': {'id': 'thread', 'status': {'type': 'active' if mode == 'resumed-active' else 'idle'}}, 'modelProvider': 'openai', 'model': 'fixture'}
    elif method in ['turn/start', 'review/start', 'thread/shellCommand']:
        assert mode == 'normal', method
        send({'method': 'turn/started', 'params': {'threadId': 'thread', 'turn': {'id': 'own', 'status': 'inProgress'}}})
        send({'method': 'item/agentMessage/delta', 'params': {'threadId': 'thread', 'turnId': 'own', 'itemId': 'own-item', 'delta': 'OWN CONTENT'}})
        send({'method': 'turn/completed', 'params': {'threadId': 'thread', 'turn': {'id': 'own', 'status': 'completed'}}})
        result = {'turn': {'id': 'own'}, 'reviewThreadId': 'thread'}
    send({'id': message['id'], 'result': result})
