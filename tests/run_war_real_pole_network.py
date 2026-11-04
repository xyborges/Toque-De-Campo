"""Actual WarGame session, non-invasive test-only mirror of a real circuit."""
from pathlib import Path
import json
import os
import socket
import subprocess
import time

root = Path(__file__).resolve().parents[1]
engine = Path(os.environ.get('GODOT_EXE', r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'))
marker = root / 'work/real-pole-first-ready.txt'
marker.unlink(missing_ok=True)
for role in ('server', 'first', 'late'):
    (root / f'work/real-pole-{role}.json').unlink(missing_ok=True)
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]

processes = []
try:
    def start(role):
        log = (root / f'work/real-pole-{role}.stdout.log').open('w', encoding='utf-8')
        display = ['--rendering-method', 'gl_compatibility', '--screen', '0', '--resolution', '800x600'] if role == 'late' else ['--headless']
        cmd = [str(engine), *display, '--max-fps', '60', '--path', str(root), '--script', 'res://tests/war_real_pole_network.gd', '--log-file', str(root / f'work/real-pole-{role}.log'), '--', '--naval-test-accounts', f'--role={role}', f'--pole-port={port}', f'--naval-data={root}/work/real-pole-{role}-data', f'--game-tls-cert={root}/work/security182/test.crt', f'--game-tls-key={root}/work/security182/test.key', f'--game-tls-ca={root}/work/security182/test.crt']
        process = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        processes.append((role, process, log))
        return process

    server = start('server')
    time.sleep(.6)
    first = start('first')
    deadline = time.monotonic() + 150
    while not marker.exists() and time.monotonic() < deadline and server.poll() is None and first.poll() is None:
        time.sleep(.2)
    if not marker.exists():
        raise RuntimeError('first client did not acknowledge both fracture heights')
    start('late')
    deadline = time.monotonic() + 160
    while time.monotonic() < deadline and any(proc.poll() is None for _, proc, _ in processes):
        time.sleep(.2)
    signatures = set()
    for role, process, log in processes:
        log.flush()
        output = (root / f'work/real-pole-{role}.stdout.log').read_text(encoding='utf-8', errors='replace')
        report_path = root / f'work/real-pole-{role}.json'
        result = json.loads(report_path.read_text(encoding='utf-8')) if report_path.exists() else {'failures': ['missing report']}
        print(role, process.poll(), result, flush=True)
        if process.poll() != 0 or result['failures'] or 'SCRIPT ERROR:' in output or 'ERROR:' in output:
            print(output[-6000:], flush=True)
            raise RuntimeError(f'{role} failed')
        signatures.add(result['report']['signature'])
    if len(signatures) != 1:
        raise RuntimeError('real circuit signatures diverged')
finally:
    for _, process, log in processes:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
        log.close()
