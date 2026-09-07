import http.client
import json
from pathlib import Path
import select
import subprocess
import sys

binary, rpc_log = sys.argv[1:]
process = subprocess.Popen([binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def output():
    assert select.select([process.stdout], [], [], 4)[0], 'fixture did not respond'
    return process.stdout.readline().strip()


def request(body=None, expected=200, method='POST', authorized=True, raw=None):
    connection = http.client.HTTPConnection('127.0.0.1', port, timeout=3)
    headers = {'Content-Type': 'application/json'}
    if authorized:
        headers['Authorization'] = 'Bearer isolated-attention-token'
    connection.request(method, '/codex/attention', raw if raw is not None else json.dumps(body), headers)
    response = connection.getresponse()
    data = response.read()
    connection.close()
    assert response.status == expected, (response.status, data[:200])
    assert 'codexAttentionBatch' in response.getheader('X-Daemon-Capabilities', '').split(',')
    return json.loads(data)


def control(command):
    process.stdin.write(command + '\n')
    process.stdin.flush()
    assert output() == 'DONE ' + command


try:
    ready = output()
    assert ready.startswith('PORT '), ready
    port = int(ready.split()[1])
    baseline = Path(rpc_log).read_text()
    assert [json.loads(line)['method'] for line in baseline.splitlines()] == ['initialize', 'fixture/seed']
    assert request({'sessionIds': []}) == {'sessions': []}
    request({'sessionIds': ['parent-session']}, expected=401, authorized=False)
    request({'sessionIds': []}, expected=404, method='GET')
    for body in [None, [], {}, {'sessionIds': None}, {'sessionIds': 'id'}, {'sessionIds': [1]}, {'sessionIds': [False]}, {'sessionIds': ['']}, {'sessionIds': ['  ']}, {'sessionIds': ['a\n']}, {'sessionIds': ['a\0']}, {'sessionIds': ['a\x7f']}, {'sessionIds': ['x', 'x']}, {'sessionIds': ['x'], 'extra': True}, {'sessionIds': ['x' * 513]}, {'sessionIds': ['😀' * 257]}, {'sessionIds': [str(index) for index in range(101)]}]:
        request(body, expected=400)
    request(expected=400, raw=b'{')
    request(expected=400, raw=b'')
    assert request(expected=413, raw=b' ' * 524289)['error'] == 'payload_too_large'
    identifiers = [str(index).zfill(3) + '値' * 509 for index in range(100)]
    maximum = request({'sessionIds': identifiers})['sessions']
    assert [row['sessionId'] for row in maximum] == identifiers
    assert all(row['sessionId'] == row['threadId'] and row['requests'] == [] and row['agentAttention'] == [] for row in maximum)
    assert len(request({'sessionIds': ['😀' * 256, 'é', 'e\u0301']})['sessions']) == 3
    sessions = request({'sessionIds': ['PaReNt-SeSsIoN', 'child-session', 'leaf-thread', 'unknown', 'parent-session']})['sessions']
    assert [row['sessionId'] for row in sessions] == ['PaReNt-SeSsIoN', 'child-session', 'leaf-thread', 'unknown', 'parent-session']
    assert [row['threadId'] for row in sessions] == ['parent-thread', 'child-thread', 'leaf-thread', 'unknown', 'parent-thread']
    parent, child, leaf, unknown, repeated_mapping = sessions
    assert set(parent) == {'sessionId', 'threadId', 'requests', 'agentAttention'}
    assert len(parent['requests']) == 1 and parent['requests'][0]['method'] == 'item/tool/requestUserInput'
    assert set(parent['requests'][0]) == {'requestId', 'method', 'params'}
    assert parent['requests'][0]['params']['threadId'] == 'parent-thread'
    assert len(leaf['requests']) == 1 and leaf['requests'][0]['method'] == 'item/permissions/requestApproval'
    assert parent['agentAttention'] == [{'threadId': 'leaf-thread', 'requestId': leaf['requests'][0]['requestId']}]
    assert child['requests'] == [] and child['agentAttention'] == []
    assert unknown['requests'] == [] and unknown['agentAttention'] == []
    assert repeated_mapping['requests'] == parent['requests']
    assert Path(rpc_log).read_text() == baseline
    control('handoff')
    handoff = request({'sessionIds': ['parent-session', 'child-session']})['sessions']
    assert handoff[0]['agentAttention'] == []
    assert handoff[1]['agentAttention'] == parent['agentAttention']
    assert Path(rpc_log).read_text() == baseline
    control('resolve')
    resolved = request({'sessionIds': ['parent-session', 'child-session', 'leaf-thread']})['sessions']
    assert all(row['agentAttention'] == [] for row in resolved)
    assert resolved[2]['requests'] == [] and len(resolved[0]['requests']) == 1
    control('complete')
    completed = request({'sessionIds': ['parent-session', 'child-session', 'leaf-thread']})['sessions']
    assert all(row['requests'] == [] and row['agentAttention'] == [] for row in completed)
    assert [json.loads(line)['method'] for line in Path(rpc_log).read_text().splitlines()] == ['initialize', 'fixture/seed', 'fixture/resolve', 'fixture/complete']
    print('PASS actual native attention batch router/auth, strict body/ID bounds, case-insensitive mapping, exact order/duplicates, inactive parent/helper notices, owner handoff and resolution without polling RPCs')
finally:
    if process.poll() is None:
        process.stdin.write('stop\n')
        process.stdin.flush()
    process.communicate(timeout=4)
    assert process.returncode == 0, process.returncode
