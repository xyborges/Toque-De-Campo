"""Actual WarGame headless session with a test-only breakable fixture."""
from pathlib import Path
import json
import socket
import subprocess
import time

root = Path(__file__).resolve().parents[1]
engine = r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
marker = root / 'work/war-breakage-first-ready.txt'
marker.unlink(missing_ok=True)
for role in ('server', 'first', 'late'):
    (root / f'work/war-breakage-{role}.json').unlink(missing_ok=True)
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
    s.bind(('127.0.0.1', 0))
    port = s.getsockname()[1]
processes = []
try:
    def start(role):
        log = (root / f'work/war-breakage-{role}.stdout.log').open('w', encoding='utf-8')
        display = ['--rendering-method', 'gl_compatibility', '--screen', '0', '--resolution', '800x600'] if role == 'late' else ['--headless']
        cmd = [engine, *display, '--max-fps', '60', '--path', str(root), '--script', 'res://tests/war_breakage_network.gd', '--log-file', str(root / f'work/war-breakage-{role}.log'), '--', '--naval-test-accounts', f'--role={role}', f'--breakage-port={port}', f'--naval-data={root}/work/war-breakage-{role}-data', f'--game-tls-cert={root}/work/security182/test.crt', f'--game-tls-key={root}/work/security182/test.key', f'--game-tls-ca={root}/work/security182/test.crt']
        proc = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        processes.append((role, proc, log))
        return proc
    server = start('server')
    time.sleep(.6)
    first = start('first')
    deadline = time.monotonic() + 150
    while not marker.exists() and time.monotonic() < deadline and server.poll() is None and first.poll() is None:
        time.sleep(.2)
    if not marker.exists():
        raise RuntimeError('first client did not acknowledge impact and explosion')
    start('late')
    deadline = time.monotonic() + 160
    while time.monotonic() < deadline and any(proc.poll() is None for _, proc, _ in processes):
        time.sleep(.2)
    for role, proc, log in processes:
        log.flush()
        out = (root / f'work/war-breakage-{role}.stdout.log').read_text(encoding='utf-8', errors='replace')
        report_path = root / f'work/war-breakage-{role}.json'
        report = json.loads(report_path.read_text(encoding='utf-8')) if report_path.exists() else {'failures': ['missing report']}
        print(role, proc.poll(), report, flush=True)
        if proc.poll() != 0 or report['failures'] or 'SCRIPT ERROR:' in out or 'ERROR:' in out:
            print(out[-6000:], flush=True)
            raise RuntimeError(role + ' failed')
finally:
    for _, proc, log in processes:
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=5)
        log.close()
