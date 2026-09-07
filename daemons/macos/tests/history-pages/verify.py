import http.client
import json
from pathlib import Path
import select
import subprocess
import sys
from urllib.parse import quote, urlencode

binary, state = sys.argv[1:]
state = Path(state)
process = subprocess.Popen([binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def output():
    assert select.select([process.stdout], [], [], 5)[0], 'fixture did not respond'
    return process.stdout.readline().strip()


def calls():
    return [json.loads(line) for line in (state / 'calls.jsonl').read_text().splitlines()]


def request(path, query=None, body=None, expected=200, headers=None, authorized=True):
    connection = http.client.HTTPConnection('127.0.0.1', port, timeout=4)
    fields = {'Content-Type': 'application/json', **(headers or {})}
    if authorized:
        fields['Authorization'] = 'Bearer isolated-attention-token'
    connection.request('GET' if body is None else 'POST', path + ('?' + urlencode(query, quote_via=quote) if query else ''), None if body is None else json.dumps(body), fields)
    response = connection.getresponse()
    data = response.read()
    connection.close()
    assert response.status == expected, (path, query, response.status, data[:200])
    assert 'codexHistoryPages' in response.getheader('X-Daemon-Capabilities', '').split(',')
    return (json.loads(data) if data else None), dict(response.getheaders())


def control(command):
    process.stdin.write(command + '\n')
    process.stdin.flush()
    assert output() == 'DONE ' + command


try:
    ready = output()
    assert ready.startswith('PORT '), ready
    port = int(ready.split()[1])
    request('/sessions/alias/turns', authorized=False, expected=401)
    assert calls() == []
    metadata, _ = request('/codex/threads/native', {'includeTurns': 'false'})
    assert metadata['thread']['turns'] == []
    imported, _ = request('/sessions/alias/import', body={'threadId': 'native', 'includeTurns': False})
    assert imported['threadId'] == 'native' and imported['thread']['turns'] == []
    assert json.loads((state / 'codex-sessions.json').read_text())['alias']['threadId'] == 'native'
    assert all(call['method'] == 'thread/read' and call['params']['includeTurns'] is False for call in calls())
    metadata, headers = request('/sessions/ALIAS/history', {'includeTurns': 'false'})
    request('/sessions/alias/history', {'includeTurns': 'false'}, expected=304, headers={'If-None-Match': headers['ETag']})
    page, _ = request('/sessions/ALIAS/turns', {'limit': '1', 'sortDirection': 'asc'})
    assert page['threadId'] == 'native'
    assert page['data'][0]['items'][0]['text'] == 'Fixture result'
    assert page['nextCursor'] == 'opaque:+/=' and page['backwardsCursor'] == 'backwards:one'
    assert calls()[-1] == {'method': 'thread/turns/list', 'params': {'threadId': 'native', 'limit': 1, 'sortDirection': 'asc', 'itemsView': 'full'}}
    later, _ = request('/sessions/alias/turns', {'cursor': page['nextCursor']})
    assert later == {'threadId': 'native', 'data': [], 'nextCursor': None, 'backwardsCursor': None}
    assert calls()[-1]['params'] == {'threadId': 'native', 'limit': 25, 'sortDirection': 'desc', 'itemsView': 'full', 'cursor': 'opaque:+/='}
    full, _ = request('/sessions/alias/history')
    assert full['thread']['turns'] == page['data'] and calls()[-1]['params']['includeTurns'] is True
    full_import, _ = request('/sessions/default-alias/import', body={'threadId': 'default-native'})
    assert len(full_import['thread']['turns']) == 1 and calls()[-1]['params']['includeTurns'] is True
    explicit, _ = request('/codex/threads/native', {'includeTurns': 'true'})
    assert len(explicit['thread']['turns']) == 1
    before = calls()
    for query in [{'limit': '0'}, {'limit': '51'}, {'limit': '01'}, {'limit': '+1'}, {'limit': '1.0'}, {'limit': '-1'}, {'limit': ' 1'}, {'cursor': ''}, {'cursor': ' '}, {'cursor': 'x\n'}, {'cursor': 'x' * 4097}, {'sortDirection': 'newest'}, {'itemsView': 'summary'}, {'extra': 'true'}]:
        request('/sessions/native/turns', query, expected=400)
    for query in [{'includeTurns': 'yes'}, {'includeTurns': ''}, {'includeTurns': '0'}, {'cursor': 'unexpected'}]:
        request('/sessions/native/history', query, expected=400)
    for body in [{'threadId': 'native', 'includeTurns': 'false'}, {'threadId': 'native', 'includeTurns': 0}, {'threadId': 'native', 'includeTurns': 1}, {'threadId': 'native', 'includeTurns': None}, {'threadId': 'native', 'extra': True}, {'threadId': 'native', 'path': ''}, {'threadId': 'native', 'path': 'x\n'}, {'threadId': 'bad\0'}]:
        request('/sessions/invalid-import/import', body=body, expected=400)
    assert calls() == before
    request('/sessions/native/turns', {'limit': '50', 'cursor': 'x' * 4096})
    assert calls()[-1]['params']['limit'] == 50
    request('/codex/threads/wrong-identity', {'includeTurns': 'false'}, expected=502)
    request('/sessions/wrong-import/import', body={'threadId': 'wrong-identity', 'includeTurns': False}, expected=502)
    assert 'wrong-import' not in json.loads((state / 'codex-sessions.json').read_text())
    for thread in ['summary', 'notLoaded', 'bad-status', 'bad-items', 'bad-id', 'missing-data', 'bad-cursor', 'long-cursor', 'control-cursor']:
        request('/sessions/' + thread + '/turns', expected=502)
    request('/sessions/duplicate/turns', expected=502)
    request('/sessions/too-many/turns', {'limit': '1'}, expected=502)
    legacy, _ = request('/sessions/legacy/turns')
    assert 'itemsView' not in legacy['data'][0]
    assert legacy['nextCursor'] is None and legacy['backwardsCursor'] is None
    for path, body in [('/sessions/provider-failure/turns', None), ('/sessions/provider-failure/history', None), ('/sessions/failed-import/import', {'threadId': 'provider-failure'})]:
        failed, _ = request(path, body=body, expected=502)
        assert 'private-upstream-marker' not in json.dumps(failed)
    for suffix in ['history', 'turns']:
        control('reset')
        request('/sessions/moving-alias/' + suffix, expected=409)
        assert json.loads((state / 'codex-sessions.json').read_text())['moving-alias']['threadId'] == 'changed'
    assert all(call['method'] in ['thread/read', 'thread/turns/list'] for call in calls())
    control('storage-failure')
    request('/sessions/unsaved-import/import', body={'threadId': 'native', 'includeTurns': False}, expected=502)
    assert (state / 'codex-sessions.json').is_dir()
    print('PASS native history pages actual router/auth, metadata/default-full reads and imports, durable mapping, ETag, full-item paging, opaque cursors, strict query/status/reply validation, sanitized failures and mapping-race fence')
finally:
    if process.poll() is None:
        process.stdin.write('stop\n')
        process.stdin.flush()
    process.communicate(timeout=5)
    assert process.returncode == 0, process.returncode
