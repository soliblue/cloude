import http.server
import json
import pathlib
import sys
import threading
import urllib.parse

state = {'requests': [], 'held': False, 'redirects': 0}
release = threading.Event()

class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *args):
        pass

    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        if url.path in ['/state', '/release']:
            if url.path == '/release':
                release.set()
            data = json.dumps(state).encode()
            self.send_response(200)
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        mode = url.path.rsplit('/', 1)[-1]
        state['requests'].append({'path': mode, 'range': self.headers.get('Range'), 'auth': self.headers.get('Authorization'), 'query': urllib.parse.parse_qs(url.query)})
        if mode == 'redirect-target':
            state['redirects'] += 1
        if mode == 'redirect':
            self.send_response(302)
            self.send_header('Location', 'http://localhost:' + str(self.server.server_port) + '/redirect-target')
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        if mode == 'hold':
            release.clear()
            state['held'] = True
            release.wait(3)
            state['held'] = False
        if mode == 'stall':
            threading.Event().wait(2)
        self.send_response(206 if mode == 'exact206' else 200)
        self.send_header('X-Daemon-Capabilities', 'codex, codexTerminal')
        if mode == 'exact206':
            self.send_header('Content-Range', 'bytes 0-4/5')
        if mode in ['exact200', 'exact206', 'hold']:
            self.send_header('Content-Length', '5')
        if mode in ['empty', 'stall']:
            self.send_header('Content-Length', '0')
        if mode == 'header-overflow':
            self.send_header('Content-Length', '6')
        if mode == 'misleading':
            self.send_header('Content-Length', '1')
        chunked = mode in ['chunked', 'overflow', 'misleading']
        if chunked:
            self.send_header('Transfer-Encoding', 'chunked')
        self.send_header('Connection', 'close')
        self.end_headers()
        if mode not in ['empty', 'stall']:
            for data in [bytes([1, 2]), bytes([3, 4, 5])] + ([bytes([6])] if mode in ['overflow', 'misleading', 'header-overflow'] else []):
                self.wfile.write((format(len(data), 'x').encode() + b'\r\n' + data + b'\r\n') if chunked else data)
                self.wfile.flush()
            if chunked:
                self.wfile.write(b'0\r\n\r\n')
        self.close_connection = True

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
server.daemon_threads = True
pathlib.Path(sys.argv[1]).write_text(str(server.server_port))
server.serve_forever()
