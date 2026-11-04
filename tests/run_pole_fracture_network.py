"""Isolated headless ENet authority and late-join test; not a WarGame test."""
from pathlib import Path
import json
import os
import socket
import subprocess
import time

root = Path(__file__).resolve().parents[1]
exe = Path(os.environ.get('GODOT_EXE', r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'))
marker = root / 'work/pole-fracture-first-ready.txt'
result = root / 'work/pole-fracture-network.json'
for path in (marker, result):
    path.unlink(missing_ok=True)
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]

processes = []
try:
    def start(role):
        log = (root / f'work/pole-fracture-network-{role}.stdout.log').open('w', encoding='utf-8')
        cmd = [str(exe), '--headless', '--max-fps', '60', '--path', str(root), '--script', 'res://tests/pole_fracture_network.gd', '--log-file', str(root / f'work/pole-fracture-network-{role}.log'), '--', f'--role={role}', f'--port={port}']
        process = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        processes.append((role, process, log))
        return process

    server = start('server')
    time.sleep(1)
    first = start('first')
    deadline = time.monotonic() + 60
    while not marker.exists() and time.monotonic() < deadline and server.poll() is None and first.poll() is None:
        time.sleep(.1)
    if not marker.exists():
        raise RuntimeError('first client did not confirm events, duplicate and authority rejection')
    start('late')
    for role, process, log in processes:
        process.wait(timeout=60)
        log.flush()
        output = (root / f'work/pole-fracture-network-{role}.stdout.log').read_text(encoding='utf-8', errors='replace')
        print(f'{role} exit={process.returncode}\n{output}')
        if process.returncode or 'SCRIPT ERROR:' in output or 'ERROR:' in output:
            raise RuntimeError(f'{role} failed')
    if not result.exists():
        raise RuntimeError('missing server report')
    report = json.loads(result.read_text(encoding='utf-8'))
    if not report['ok'] or report['server_heights_cm'] != [150, 620]:
        raise RuntimeError(f'peers diverged: {report}')
    print(json.dumps(report, ensure_ascii=False, indent=2))
finally:
    for _, process, log in processes:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
        log.close()
