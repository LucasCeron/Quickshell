#!/usr/bin/env python3
"""Open every QML file in qmlls and report its actual LSP diagnostics."""
import argparse
import json
from pathlib import Path
import queue
import subprocess
import threading
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
args = parser.parse_args()
root = args.root.resolve()
files = sorted(root.rglob('*.qml'))
messages = queue.Queue()
server = subprocess.Popen(['/usr/lib/qt6/bin/qmlls', '--no-cmake-calls', '-I', '/usr/lib/qt6/qml'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)

def read():
    while True:
        headers = {}
        while True:
            line = server.stdout.readline()
            if not line: return
            if line == b'\r\n': break
            key, value = line.decode().split(':', 1)
            headers[key.lower()] = value.strip()
        messages.put(json.loads(server.stdout.read(int(headers['content-length']))))

def send(method, params, identifier=None):
    message = {'jsonrpc': '2.0', 'method': method, 'params': params}
    if identifier is not None: message['id'] = identifier
    body = json.dumps(message).encode()
    server.stdin.write(f'Content-Length: {len(body)}\r\n\r\n'.encode() + body)
    server.stdin.flush()

threading.Thread(target=read, daemon=True).start()
try:
    send('initialize', {'processId': None, 'rootUri': root.as_uri(), 'capabilities': {}, 'workspaceFolders': [{'uri': root.as_uri(), 'name': 'config'}]}, 1)
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        if messages.get(timeout=20).get('id') == 1: break
    else: raise RuntimeError('qmlls did not initialize')
    send('initialized', {})
    for path in files:
        send('textDocument/didOpen', {'textDocument': {'uri': path.as_uri(), 'languageId': 'qml', 'version': 1, 'text': path.read_text()}})
    results = {}
    deadline = time.monotonic() + 45
    while len(results) < len(files) and time.monotonic() < deadline:
        try: message = messages.get(timeout=1)
        except queue.Empty: continue
        if message.get('method') == 'textDocument/publishDiagnostics':
            params = message['params']
            results[params['uri']] = params.get('diagnostics', [])
    failed = False
    for path in files:
        diagnostics = results.get(path.as_uri())
        if diagnostics is None:
            print(f'{path.relative_to(root)}: NO LSP RESPONSE')
            failed = True
            continue
        print(f'{path.relative_to(root)}: {len(diagnostics)} diagnostics')
        for d in diagnostics:
            print(f'  {d.get("severity")}: {d["range"]["start"]["line"] + 1}: {d["message"]}')
            if d.get('severity', 1) <= 2: failed = True
    print(f'LSP: {len(results)}/{len(files)} files checked')
finally:
    server.terminate()
    server.wait(timeout=5)
raise SystemExit(1 if failed else 0)
