#!/usr/bin/python3
import json
import os
import sys
import time

root = os.environ['CODEX_HOME']
mode = open(os.path.join(root, 'mode'), encoding='utf-8').read()
record = os.path.join(root, mode + '.jsonl')
thread_id = 'shell-thread'
turn_id = 'shell-turn'

def emit(value):
    print(json.dumps(value), flush=True)

def notify(method, params):
    emit({'method': method, 'params': {'threadId': thread_id, **params}})

for line in sys.stdin:
    message = json.loads(line)
    with open(record, 'a', encoding='utf-8') as file:
        file.write(json.dumps(message) + '\n')
    method = message.get('method')
    if method == 'initialized':
        continue
    result = {}
    if method == 'initialize':
        result = {'initialized': True}
    elif method == 'account/read':
        result = {'account': {'type': 'apiKey' if mode == 'apikey' else 'chatgpt'}}
    elif method == 'config/read':
        result = {'config': {}}
    elif method in ('thread/start', 'thread/resume'):
        result = {'thread': {'id': thread_id}, 'model': 'fixture-model', 'modelProvider': 'openai'}
    elif method == 'thread/shellCommand':
        assert message['params'] == {'threadId': thread_id, 'command': "printf 'hello shell'", 'timeoutMs': 3600000}
        if mode in ['late', 'cancel-before-id', 'journal-failure']:
            emit({'id': message['id'], 'result': {}})
            if mode in ['cancel-before-id', 'journal-failure']:
                open(os.path.join(root, 'acknowledged'), 'w').close()
                time.sleep(0.2)
        notify('turn/started', {'turn': {'id': turn_id}})
        notify('item/started', {'item': {'id': 'command', 'type': 'commandExecution', 'command': "printf 'hello shell'", 'source': 'userShell', 'status': 'inProgress'}})
        if mode not in ['cancel-before-id', 'journal-failure']:
            notify('item/commandExecution/outputDelta', {'itemId': 'command', 'delta': 'hello shell'})
            notify('item/completed', {'item': {'id': 'command', 'type': 'commandExecution', 'command': "printf 'hello shell'", 'source': 'userShell', 'status': 'completed', 'aggregatedOutput': 'hello shell', 'exitCode': 0}})
            notify('turn/completed', {'turn': {'id': turn_id, 'status': 'completed'}})
        if mode in ['late', 'cancel-before-id', 'journal-failure']:
            continue
    elif method == 'turn/interrupt':
        assert message['params'] == {'threadId': thread_id, 'turnId': turn_id}
        notify('turn/completed', {'turn': {'id': turn_id, 'status': 'interrupted'}})
    else:
        emit({'id': message['id'], 'error': {'message': 'Unexpected fixture method: ' + str(method)}})
        continue
    emit({'id': message['id'], 'result': result})
