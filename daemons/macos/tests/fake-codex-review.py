#!/usr/bin/python3
import json
import os
import sys

root = os.environ['CODEX_HOME']
mode = open(os.path.join(root, 'mode'), encoding='utf-8').read()
record = os.path.join(root, mode + '.jsonl')
thread_id = 'review-thread'
turn_id = 'review-turn'
account_reads = 0


def emit(value):
    print(json.dumps(value), flush=True)


def notify(method, params):
    emit({'method': method, 'params': {'threadId': thread_id, **params}})


def completed(status='completed'):
    if status == 'completed':
        notify('item/completed', {'item': {'id': 'exited', 'type': 'exitedReviewMode', 'review': 'Review result'}})
    if mode == 'report-first':
        notify('item/completed', {'item': {'id': 'assistant', 'type': 'agentMessage', 'text': 'Review result'}})
    notify('turn/completed', {'turn': {'id': turn_id, 'status': status}})


for line in sys.stdin:
    message = json.loads(line)
    with open(record, 'a', encoding='utf-8') as file:
        file.write(json.dumps(message) + '\n')
    method = message.get('method')
    if method == 'initialized':
        continue
    if not method:
        if message.get('id') == 700:
            assert message.get('result') == {'decision': 'accept'}
            completed()
        continue
    result = {}
    if method == 'initialize':
        result = {'initialized': True}
    elif method == 'account/read':
        account_reads += 1
        result = {'account': {'type': 'apiKey' if mode == 'apikey' or mode == 'account-transition' and account_reads > 2 else 'chatgpt'}}
    elif method == 'config/read':
        result = {'config': {}}
    elif method == 'account/rateLimits/read':
        result = {'rateLimits': {'primary': {'usedPercent': 100 if mode == 'quota' else 0}}}
    elif method in ('thread/start', 'thread/resume'):
        result = {'thread': {'id': thread_id}, 'model': 'fixture-model', 'modelProvider': 'paid' if mode == 'badprovider' else 'openai'}
    elif method == 'review/start':
        assert message['params']['delivery'] == 'inline'
        notify('turn/started', {'turn': {'id': turn_id}})
        notify('item/started', {'item': {'id': 'entered', 'type': 'enteredReviewMode', 'review': 'Review local changes'}})
        notify('item/completed', {'item': {'id': 'entered', 'type': 'enteredReviewMode', 'review': 'Review local changes'}})
        if mode == 'delta':
            notify('item/agentMessage/delta', {'delta': 'Review result'})
        if mode == 'plan':
            notify('item/started', {'item': {'id': 'plan-item', 'type': 'plan', 'text': 'Inspect files'}})
            notify('item/plan/delta', {'itemId': 'plan-item', 'delta': ' then test'})
            notify('item/completed', {'item': {'id': 'plan-item', 'type': 'plan', 'text': 'Inspect files then test'}})
        if mode == 'final':
            notify('item/completed', {'item': {'id': 'assistant', 'type': 'agentMessage', 'text': 'Review result'}})
        if mode == 'approval':
            emit({'id': 700, 'method': 'item/commandExecution/requestApproval', 'params': {'threadId': thread_id, 'command': 'git diff'}})
        elif mode == 'account-transition':
            notify('account/updated', {})
        elif mode != 'interrupt':
            completed()
        result = {'turn': {'id': turn_id}, 'reviewThreadId': thread_id}
    elif method == 'turn/interrupt':
        assert message['params'] == {'threadId': thread_id, 'turnId': turn_id}
        completed('interrupted')
    else:
        emit({'id': message['id'], 'error': {'message': 'Unexpected fixture method: ' + method}})
        continue
    emit({'id': message['id'], 'result': result})
