#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess
import sys
import threading

root = Path(__file__).parent
allowed = {'initialize', 'initialized', 'account/read', 'config/read', 'command/exec', 'command/exec/write', 'command/exec/resize', 'command/exec/terminate'}
child = subprocess.Popen([root.joinpath('executable').read_text(), *sys.argv[1:]], stdin=subprocess.PIPE, stdout=sys.stdout.buffer, stderr=open(root / 'codex-stderr.log', 'wb'))

(root / 'child.pid').write_text(str(child.pid))

def forward():
    for line in sys.stdin.buffer:
        message = json.loads(line)
        if message.get('method') not in allowed:
            child.terminate()
            raise RuntimeError('non-terminal protocol method rejected')
        with open(root / 'protocol.jsonl', 'a') as log:
            log.write(json.dumps({'method': message['method']}) + '\n')
        child.stdin.write(line)
        child.stdin.flush()
    child.stdin.close()

threading.Thread(target=forward, daemon=True).start()
sys.exit(child.wait())
