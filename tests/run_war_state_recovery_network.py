"""Run the full-map recovery regression without writing artifacts into the repo."""
from pathlib import Path
import argparse
import json
import os
import socket
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('--engine', required=True)
parser.add_argument('--tls-dir', type=Path, required=True)
parser.add_argument('--without-vehicle-recovery', action='store_true')
parser.add_argument('--graphics', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
folder = Path(tempfile.mkdtemp(prefix='campo-recovery-network-'))
print('REPORTS', folder, flush=True)
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]
jobs = []
try:
    for role in ('server', 'client'):
        env = os.environ.copy()
        env['CAMPO_RECOVERY_DIR'] = str(folder)
        env['APPDATA'] = str(folder / (role + '-appdata'))
        log = (folder / (role + '.log')).open('w', encoding='utf-8')
        command = [args.engine, '--path', str(root), '--script',
                   'tests/war_state_recovery_network.gd', '--log-file',
                   str(folder / (role + '-engine.log'))]
        command += ['--resolution', '1280x800'] if args.graphics and role == 'client' else ['--headless']
        command += ['--', '--naval-test-accounts', '--role=' + role,
                    '--war-port=' + str(port), '--naval-data=' + str(folder / (role + '-data')),
                    '--game-tls-cert=' + str(args.tls_dir / 'test.crt'),
                    '--game-tls-key=' + str(args.tls_dir / 'test.key'),
                    '--game-tls-ca=' + str(args.tls_dir / 'test.crt'), '--game-tls-host=localhost']
        if args.without_vehicle_recovery:
            command.append('--without-vehicle-recovery')
        jobs.append((role, subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                     creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0)), log))
        time.sleep(.5)
    deadline = time.monotonic() + 220
    while time.monotonic() < deadline and any(proc.poll() is None for _, proc, _ in jobs):
        for role, proc, log in jobs:
            log.flush()
            output = (folder / (role + '.log')).read_text(encoding='utf-8', errors='replace')
            if 'SCRIPT ERROR:' in output or 'Parse Error:' in output:
                raise RuntimeError(role + '\n' + output[-5000:])
        time.sleep(.5)
    reports = {}
    for role, proc, log in jobs:
        log.flush()
        report_file = folder / (role + '.json')
        if proc.poll() != 0 or not report_file.exists():
            raise RuntimeError(role + '\n' + (folder / (role + '.log')).read_text(errors='replace')[-5000:])
        reports[role] = json.loads(report_file.read_text(encoding='utf-8'))
        if reports[role]['failures']:
            raise RuntimeError(str(reports[role]['failures']))
    (folder / 'results.json').write_text(json.dumps(reports, indent=2), encoding='utf-8')
    print(json.dumps(reports), flush=True)
finally:
    for _, proc, log in jobs:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=8)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=8)
        log.close()
