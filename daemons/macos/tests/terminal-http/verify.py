import base64
import hashlib
import http.client
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import uuid

root = Path(sys.argv[1])
source_auth = Path(os.environ.get('CODEX_HOME', str(Path.home() / '.codex'))) / 'auth.json'
auth_digest = hashlib.sha256(source_auth.read_bytes()).digest()
(root / 'codex').mkdir(mode=0o700)
(root / 'work').mkdir(mode=0o700)
shutil.copyfile(source_auth, root / 'codex' / 'auth.json')
os.chmod(root / 'codex' / 'auth.json', 0o600)
(root / 'token').write_text(secrets.token_urlsafe(32))
os.chmod(root / 'token', 0o600)
(root / 'executable').write_text(sys.argv[2])
shutil.copyfile(Path(__file__).parent / 'codex-proxy.py', root / 'codex-proxy.py')
os.chmod(root / 'codex-proxy.py', 0o700)
with socket.socket() as available:
    available.bind(('127.0.0.1', 0))
    port = available.getsockname()[1]
environment = {key: value for key, value in os.environ.items() if key not in ['OPENAI_API_KEY', 'ANTHROPIC_API_KEY', 'CODEX_API_KEY']}
environment.update(CLOUDE_PORT=str(port), CLOUDE_AUTH_TOKEN=(root / 'token').read_text(), CLOUDE_DATA=str(root / 'state'), CODEX_HOME=str(root / 'codex'), CLOUDE_CODEX_BIN=str(root / 'codex-proxy.py'))
process = subprocess.Popen([str(root / 'terminal-http')], env=environment, stdout=open(root / 'fixture.log', 'wb'), stderr=subprocess.STDOUT, start_new_session=True)
headers = {'Authorization': 'Bearer ' + (root / 'token').read_text(), 'Content-Type': 'application/json'}

def request(method, path, body=None):
    connection = http.client.HTTPConnection('127.0.0.1', port, timeout=25)
    connection.request(method, path, None if body is None else json.dumps(body), headers)
    response = connection.getresponse()
    value = json.loads(response.read())
    connection.close()
    return response.status, value

def wait(predicate, label, seconds=10):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.02)
    raise AssertionError(label)

session = str(uuid.uuid4())
path = '/sessions/' + session + '/terminals'
stream = None
try:
    wait(lambda: socket.socket().connect_ex(('127.0.0.1', port)) == 0, 'fixture listener')
    status, terminal = request('POST', path, {'requestId': str(uuid.uuid4()), 'path': str(root / 'work'), 'rows': 24, 'cols': 80, 'fullAccess': True})
    assert status == 202, (status, terminal)
    terminal_path = path + '/' + terminal['terminalId']
    stream = http.client.HTTPConnection('127.0.0.1', port, timeout=25)
    stream.request('GET', terminal_path + '/stream?after_seq=-1', headers=headers)
    response = stream.getresponse()
    assert response.status == 200
    events = []
    output = bytearray()
    closed = threading.Event()
    def read_stream():
        for line in response:
            if line.strip():
                event = json.loads(line)
                events.append(event)
                if event.get('type') == 'terminal_output':
                    output.extend(base64.b64decode(event['deltaBase64']))
        closed.set()
    reader = threading.Thread(target=read_stream, daemon=True)
    reader.start()
    wait(lambda: any(event.get('type') == 'terminal_ready' for event in events), 'live ready')
    assert not closed.is_set()
    writer = str(uuid.uuid4())
    sequence = 0
    def send(data):
        global sequence
        status, value = request('POST', terminal_path + '/input', {'writerId': writer, 'sequence': sequence, 'deltaBase64': base64.b64encode(data).decode()})
        assert status == 200, (status, value)
        sequence += 1
        return value
    send(b"stty -echo; printf 'LIVE_READY\\n'\n")
    wait(lambda: b'LIVE_READY\r\n' in output, 'future live output')
    payload = 'Unicode paste café 日本語\nsecond line\n'.encode()
    send(b"cat > pasted.txt <<'AFTOPASTE'\n" + payload + b"AFTOPASTE\nprintf 'PASTE_OK\\n'\n")
    wait(lambda: (root / 'work' / 'pasted.txt').exists(), 'paste file')
    assert (root / 'work' / 'pasted.txt').read_bytes() == payload
    once = b"printf x >> once.txt; printf 'ONCE_OK\\n'\n"
    once_sequence = sequence
    send(once)
    status, duplicate = request('POST', terminal_path + '/input', {'writerId': writer, 'sequence': once_sequence, 'deltaBase64': base64.b64encode(once).decode()})
    assert status == 200 and duplicate['duplicate'] is True
    send(b"printf 'DUPLICATE_BARRIER\\n'\n")
    wait(lambda: b'DUPLICATE_BARRIER\r\n' in output, 'duplicate-input barrier')
    assert (root / 'work' / 'once.txt').read_bytes() == b'x'
    status, value = request('POST', terminal_path + '/resize', {'rows': 37, 'cols': 111})
    assert status == 200, (status, value)
    send(b"stty size; printf 'RESIZE_OK\\n'\n")
    wait(lambda: b'37 111\r\n' in output, 'real PTY resize')
    send(b"sleep 30; printf 'INTERRUPT_FINISHED\\n'\n")
    time.sleep(0.2)
    send(b'\x03')
    send(b"printf 'AFTER_INTERRUPT\\n'\n")
    wait(lambda: b'AFTER_INTERRUPT\r\n' in output, 'Ctrl-C interrupts foreground command')
    send(b"/usr/bin/printf '%01200000d' 0; printf '\\nBURST_DONE\\n'\n")
    wait(lambda: b'BURST_DONE\r\n' in output, 'output burst', seconds=20)
    replay = http.client.HTTPConnection('127.0.0.1', port, timeout=10)
    replay.request('GET', terminal_path + '/stream?after_seq=-1', headers=headers)
    replay_response = replay.getresponse()
    replay_events = []
    for line in replay_response:
        if line.strip():
            event = json.loads(line)
            replay_events.append(event)
            if event.get('type') == 'terminal_ready':
                break
    assert replay_events[0]['type'] == 'terminal_gap'
    sequences = [event['seq'] for event in replay_events if 'seq' in event]
    assert sequences == list(range(sequences[0], sequences[-1] + 1))
    replay.close()
    status, value = request('DELETE', terminal_path)
    assert status == 200, (status, value)
    wait(closed.is_set, 'live HTTP stream closes after terminate')
    assert events[-1]['status'] in ['exited', 'failed']
    status, listing = request('GET', path)
    assert listing['terminals'][0]['status'] != 'running'
    request('POST', '/shutdown')
    methods = [json.loads(line)['method'] for line in (root / 'protocol.jsonl').read_text().splitlines()]
    assert not any(method in methods for method in ['turn/start', 'review/start', 'turn/steer', 'account/login/start', 'account/rateLimits/read'])
    assert hashlib.sha256(source_auth.read_bytes()).digest() == auth_digest
    print(json.dumps({'result': 'passed', 'codexVersion': subprocess.check_output([sys.argv[2], '--version'], text=True).strip(), 'nativeHTTP': True, 'futureLiveOutput': True, 'pasteBytes': len(payload), 'duplicateInputAppliedOnce': True, 'resize': '37x111', 'ctrlC': True, 'gapReplay': True, 'retainedEvents': len(sequences), 'liveOutputBytes': len(output), 'terminateClosedStream': True, 'modelCalls': 0, 'authUnchanged': True, 'protocolMethods': sorted(set(methods))}))
finally:
    if stream:
        stream.close()
    os.killpg(process.pid, signal.SIGTERM)
    process.wait(timeout=5)
    if (root / 'child.pid').exists():
        child_pid = (root / 'child.pid').read_text()
        wait(lambda: not subprocess.run(['/bin/ps', '-p', child_pid, '-o', 'pid='], capture_output=True, text=True).stdout.strip(), 'own app-server process exits', seconds=5)
    print(json.dumps({'ownProcessesCleaned': True, 'temporaryState': 'removed by fixture trap'}))
