#!/usr/bin/env python3
import base64
import json
import sys
import time

commands = {}

def send(value):
    print(json.dumps(value), flush=True)

def output(process_id, data):
    send({'method': 'command/exec/outputDelta', 'params': {'processId': process_id, 'deltaBase64': base64.b64encode(data).decode(), 'stream': 'stdout', 'capReached': False}})

for line in sys.stdin:
    message = json.loads(line)
    method = message.get('method')
    params = message.get('params', {})
    if method == 'initialize':
        send({'id': message['id'], 'result': {}})
    elif method == 'account/read':
        send({'id': message['id'], 'result': {'account': {'type': 'chatgpt'}}})
    elif method == 'config/read':
        if params['cwd'].endswith('/slow'):
            time.sleep(0.15)
        send({'id': message['id'], 'result': {'config': {'openai_base_url': 'https://invalid.example/v1'} if params['cwd'].endswith('/denied') else {}}})
    elif method == 'command/exec':
        commands[params['processId']] = message['id']
        output(params['processId'], b'hello')
    elif method == 'command/exec/write':
        data = base64.b64decode(params['deltaBase64'])
        if data == b'deny':
            send({'id': message['id'], 'error': {'message': 'fixture write denied'}})
        elif data == b'ambiguous':
            output(params['processId'], b'ambiguous-write-once')
        else:
            if data == b'burst':
                for index in range(40):
                    output(params['processId'], bytes([65 + index % 26]) * 200)
            else:
                output(params['processId'], data)
            send({'id': message['id'], 'result': {}})
    elif method == 'command/exec/resize':
        if params['size']['rows'] == 666:
            send({'id': message['id'], 'error': {'message': 'fixture resize denied'}})
        else:
            send({'id': message['id'], 'result': {}})
    elif method == 'command/exec/terminate':
        send({'id': message['id'], 'result': {}})
        send({'id': commands[params['processId']], 'result': {'exitCode': 0, 'stdout': '', 'stderr': ''}})
