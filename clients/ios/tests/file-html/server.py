import http.server
import json
import pathlib
import sys

class Handler(http.server.BaseHTTPRequestHandler):
    requests = []

    def do_GET(self):
        if self.path == '/counts':
            body = json.dumps(self.requests).encode()
        else:
            self.requests.append(self.path)
            body = b'<!doctype html><p>network probe</p>'
        self.send_response(200)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass

server = http.server.HTTPServer(('127.0.0.1', 0), Handler)
pathlib.Path(sys.argv[1]).write_text(str(server.server_port))
server.serve_forever()
