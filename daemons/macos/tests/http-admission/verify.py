import json
import socket
import subprocess
import sys
import time
from pathlib import Path

binary, temporary = sys.argv[1:]
authorization = b'Authorization: Bearer isolated-fixture-token\r\n'

def connect(port):
    connection = socket.create_connection(('127.0.0.1', port), timeout=2)
    connection.settimeout(2)
    return connection


def receive(connection):
    output = bytearray()
    while True:
        data = connection.recv(65536)
        if not data:
            return bytes(output)
        output.extend(data)
        if b'\r\n\r\n' in output:
            head, body = output.split(b'\r\n\r\n', 1)
            length = next((int(line.split(b':', 1)[1]) for line in head.split(b'\r\n') if line.lower().startswith(b'content-length:')), None)
            if length is not None and len(body) >= length:
                return bytes(output)


def start(updating=False):
    log = Path(temporary) / ('updating.log' if updating else 'normal.log')
    with log.open('w') as output:
        process = subprocess.Popen([binary] + (['--updating'] if updating else []), stdout=output, stderr=subprocess.DEVNULL)
    deadline = time.monotonic() + 3
    while time.monotonic() < deadline and not log.read_text().startswith('PORT '):
        time.sleep(.01)
    assert log.read_text().startswith('PORT ')
    return process, int(log.read_text().splitlines()[0].split()[1]), log


def status(port, headers, expected, body=b'', authenticated=True):
    with connect(port) as connection:
        connection.sendall(b'POST /fixture HTTP/1.1\r\n' + (authorization if authenticated else b'') + headers + b'\r\n' + body)
        response = receive(connection)
        assert response.startswith(f'HTTP/1.1 {expected} '.encode()), response[:100]
        assert b'100 Continue' not in response
        return response


process, port, log = start()
try:
    for size in [1, 1048576, 1048577, 16777217]:
        status(port, f'Content-Length: {size}\r\nExpect: 100-continue\r\n'.encode(), 401, authenticated=False)
    status(port, b'Content-Length: 16777217\r\nExpect: 100-continue\r\n', 413)
    for headers in [b'Content-Length: -1\r\n', b'Content-Length: +1\r\n', b'Content-Length: invalid\r\n', b'Content-Length: \r\n', b'Content-Length: 9999999999999999999999999999\r\n', b'Content-Length: 1\r\nContent-Length: 1\r\n', b'Transfer-Encoding: chunked\r\n', b'Content-Length: 1\r\nTransfer-Encoding: chunked\r\n', b'Bad Header: value\r\n', b'NoColon\r\n']:
        status(port, headers, 400)
    status(port, b'Content-Length: 1\r\n', 400, body=b'ABCD')
    status(port, b'Expect: something-else\r\n', 417)
    status(port, b'X-Filler: ' + b'x' * 33000 + b'\r\n', 431)
    header_filler = 32768 - len(b'POST /fixture HTTP/1.1\r\n' + authorization + b'X-Filler: \r\n\r\n')
    status(port, b'X-Filler: ' + b'x' * header_filler + b'\r\n', 200)
    maximum = status(port, b'Content-Length: 16777216\r\n', 200, body=b'x' * 16777216)
    assert json.loads(maximum.split(b'\r\n\r\n', 1)[1])['bodyBytes'] == 16777216
    with connect(port) as connection:
        connection.sendall(b'POST /fixture HTTP/1.1\r\n' + authorization + b'Content-Length: 4\r\nExpect: 100-continue\r\n\r\n')
        assert connection.recv(1024) == b'HTTP/1.1 100 Continue\r\n\r\n'
        connection.sendall(b'AB')
        time.sleep(.02)
        connection.sendall(b'CD')
        response = receive(connection)
        assert response.startswith(b'HTTP/1.1 200 ')
        assert json.loads(response.split(b'\r\n\r\n', 1)[1])['bodyBytes'] == 4
    with connect(port) as connection:
        connection.sendall(b'POST /fixture HTTP/1.1\r\n' + authorization + b'Content-Length: 4\r\n\r\n')
        time.sleep(.02)
        connection.sendall(b'ABCD')
        connection.shutdown(socket.SHUT_WR)
        assert receive(connection).startswith(b'HTTP/1.1 200 ')
    with connect(port) as connection:
        connection.sendall(b'POST /aborted HTTP/1.1\r\n' + authorization + b'Content-Length: 100\r\n\r\nshort')
    with connect(port) as connection:
        connection.sendall(b'POST /slow-body HTTP/1.1\r\n' + authorization + b'Content-Length: 100\r\n\r\nshort')
        assert receive(connection).startswith(b'HTTP/1.1 408 ')
    with connect(port) as connection:
        connection.sendall(b'POST /slow-head HTTP/1.1\r\nX: ')
        assert receive(connection).startswith(b'HTTP/1.1 408 ')
    with connect(port) as connection:
        connection.sendall(b'GET /stream HTTP/1.1\r\n' + authorization + b'\r\n')
        streamed = receive(connection)
        assert streamed.startswith(b'HTTP/1.1 200 ')
        assert b'{"future":true}\n' in streamed
    with connect(port) as connection:
        connection.sendall(b'GET /wait HTTP/1.1\r\n' + authorization + b'\r\n')
        deadline = time.monotonic() + 2
        while 'WORK_STARTED' not in log.read_text() and time.monotonic() < deadline:
            time.sleep(.01)
        assert 'WORK_STARTED' in log.read_text()
    deadline = time.monotonic() + 1
    while 'WORK_CANCELLED' not in log.read_text() and time.monotonic() < deadline:
        time.sleep(.01)
    assert 'WORK_CANCELLED' in log.read_text(), log.read_text()
    assert 'WORK_TIMED_OUT' not in log.read_text()
    assert 'DISPATCH /aborted' not in log.read_text()
    assert 'DISPATCH /slow-' not in log.read_text()
    print('PASS native HTTP auth before body, strict framing, 32 KiB headers, exact body, authorized Expect, FIN, deadlines and disconnect cancellation')
finally:
    process.terminate()
    process.wait(timeout=3)

process, port, log = start(True)
try:
    status(port, b'Content-Length: 8\r\nExpect: 100-continue\r\n', 503)
    assert 'DISPATCH' not in log.read_text()
    print('PASS native HTTP update reservation prevents 100 Continue and handler dispatch')
finally:
    process.terminate()
    process.wait(timeout=3)
