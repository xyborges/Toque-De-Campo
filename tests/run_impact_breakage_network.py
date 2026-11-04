"""Local isolated authority/late-join test, using one server and two clients."""
from pathlib import Path
import os
import socket
import subprocess
import time

root = Path(__file__).resolve().parents[1]
exe = Path(os.environ.get('GODOT_EXE', r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'))
marker = root / 'work' / 'impact-first-ready.txt'
result = root / 'work' / 'impact-breakage-network.json'
for path in (marker, result):
    path.unlink(missing_ok=True)
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]

processes = []
try:
    def start(role):
        log = (root / 'work' / f'impact-network-{role}.stdout.log').open('w', encoding='utf-8')
        proc = subprocess.Popen([str(exe), '--headless', '--max-fps', '60', '--path', str(root), '--script', 'res://tests/impact_breakage_network.gd', '--log-file', str(root / 'work' / f'impact-network-{role}.log'), '--', f'--role={role}', f'--port={port}'], stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        processes.append((role, proc, log))
        return proc
    server = start('server')
    time.sleep(1)
    first = start('first')
    deadline = time.monotonic() + 60
    while not marker.exists() and time.monotonic() < deadline and server.poll() is None and first.poll() is None:
        time.sleep(.1)
    if not marker.exists():
        raise RuntimeError('first client did not receive the authority event')
    late = start('late')
    for role, process, log in processes:
        process.wait(timeout=60)
        log.flush()
        output = (root / 'work' / f'impact-network-{role}.stdout.log').read_text(encoding='utf-8', errors='replace')
        print(f'{role} exit={process.returncode}\n{output}')
        if process.returncode or 'SCRIPT ERROR:' in output or 'ERROR:' in output:
            raise RuntimeError(f'{role} failed')
    if not result.exists():
        raise RuntimeError('server did not record converged state')
    print(result.read_text(encoding='utf-8'))
finally:
    for role, process, log in processes:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
        log.close()
