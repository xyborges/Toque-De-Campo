"""Exercise the exported updater against a controlled local HTTP server."""
import sys
import base64
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parent
PUBLIC = ROOT / 'published'
WORK = ROOT / 'build' / 'validation' / str(time.time_ns())
if '--xampp' in sys.argv: PUBLIC = ROOT / 'xampp' / 'toque-de-campo'
EXE = PUBLIC / 'ToqueDeCampo.exe'

def main():
    WORK.mkdir(parents=True, exist_ok=True)
    original = json.loads((PUBLIC / 'manifest.json').read_text())
    payload = json.loads(base64.b64decode(original['payload']))
    behavior = {'bad_signature': False, 'bad_zip': False, 'new_manifest': None, 'packages': 0, 'manifests': 0}

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            path = self.path.split('?')[0]
            if '--xampp' in sys.argv and path.startswith('/toque-de-campo/'):
                path = path[len('/toque-de-campo'):]
            if path == '/manifest.json':
                behavior['manifests'] += 1
                envelope = dict(behavior['new_manifest'] or original)
                if behavior['bad_signature']: envelope['signature'] = base64.b64encode(b'wrong').decode()
                data = json.dumps(envelope).encode()
            elif path.startswith('/releases/'):
                behavior['packages'] += 1
                data = b'corrupted' if behavior['bad_zip'] else (PUBLIC / payload['archive']).read_bytes()
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        def log_message(self, *args): pass

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f'http://127.0.0.1:{server.server_port}' + ('/toque-de-campo' if '--xampp' in sys.argv else '')
    results = []

    def check(name, root, needle, target=url, expected=0):
        log = WORK / (name + '.log')
        process = subprocess.run([str(EXE), '--headless', '--log-file', str(log), '--', '--check-only',
            '--data-root', str(WORK / root), '--update-server', target], capture_output=True, timeout=90,
            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        text = log.read_text(encoding='utf-8') if log.exists() else ''
        if process.returncode != expected or needle not in text or 'SCRIPT ERROR:' in text:
            raise AssertionError(f'{name}: exit={process.returncode}\n{text}\n{process.stderr!r}')
        results.append(name)

    check('first-install', 'profile', 'Atualização instalada.')
    assert behavior['packages'] == 1
    check('no-redownload', 'profile', 'Nenhum download necessário.')
    assert behavior['packages'] == 1
    check('offline-keeps-installed', 'profile', 'Servidor indisponível.', 'http://127.0.0.1:1')
    behavior['bad_signature'] = True
    check('invalid-signature', 'profile', 'Assinatura da atualização inválida.')
    assert behavior['packages'] == 1
    behavior['bad_signature'] = False
    behavior['bad_zip'] = True
    check('corrupt-download', 'corrupt-profile', 'Download incompleto ou alterado.', expected=1)
    assert not (WORK / 'corrupt-profile' / 'installed.json').exists()
    behavior['bad_zip'] = False
    # A valid signed higher build exercises the second atomic pointer replacement.
    newer = dict(payload)
    newer['version'] += 1
    newer['version_name'] = 'validation-update'
    newer['archive'] = f'releases/game-{newer["version"]}-{newer["sha256"][:12]}.zip'
    candidate = WORK / 'new-payload.json'
    candidate.write_text(json.dumps(newer), encoding='utf-8')
    signed = WORK / 'new-envelope.json'
    from publish import DEFAULT_GODOT, run
    run(DEFAULT_GODOT, '--path', ROOT / 'launcher', '--script', ROOT / 'launcher' / 'sign.gd',
        '--', 'sign', ROOT / 'private' / 'release-private.pem', candidate, signed)
    behavior['new_manifest'] = json.loads(signed.read_text())
    check('upgrade-installed', 'profile', 'Atualização instalada.')
    state = json.loads((WORK / 'profile' / 'installed.json').read_text())
    assert json.loads(base64.b64decode(state['payload']))['version'] == newer['version']
    behavior['new_manifest'] = None
    count = behavior['packages']
    check('reject-downgrade', 'profile', 'mais recente que a do servidor')
    assert behavior['packages'] == count
    server.shutdown()
    result = {'passed': results, 'manifest_requests': behavior['manifests'], 'package_requests': behavior['packages']}
    (WORK / 'results.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result))

if __name__ == '__main__': main()
