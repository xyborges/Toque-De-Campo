from pathlib import Path
import argparse
import json
import secrets
import subprocess
import time

root = Path.cwd()
engine = r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=3014)
parser.add_argument('--prepare-only', action='store_true')
args = parser.parse_args()
credentials = root / 'work/ubuntu-war-passenger-credentials.json'
if not credentials.exists():
    credentials.write_text(json.dumps({'username': 'qa_warseat_' + secrets.token_hex(5),
                                       'password': secrets.token_urlsafe(24), 'registered': False}), encoding='utf-8')
if args.prepare_only:
    subprocess.run([engine, '--headless', '--path', str(root), '--log-file', str(root / 'work/ubuntu-war-passengers-parse.log'), '--script',
                    'tests/ubuntu_war_passengers.gd', '--check-only'], check=True)
    print('Passenger smoke-test sources parse. Private third-account credentials are prepared; no login or game connection was attempted.')
    raise SystemExit(0)
processes = []
try:
    for role in ('operator', 'opponent', 'passenger'):
        (root / f'tests/ubuntu-war-passengers-{role}.json').unlink(missing_ok=True)
        (root / f'work/ubuntu-war-passengers-{role}.stage.json').unlink(missing_ok=True)
    for role in ('operator', 'opponent', 'passenger'):
        log = (root / f'work/ubuntu-war-passengers-{role}.stdout.log').open('w', encoding='utf-8')
        display = ['--screen', '0', '--position', '20,20', '--resolution', '1280x800'] if role == 'passenger' else ['--headless']
        cmd = [engine, *display, '--max-fps', '60', '--path', str(root), '--script',
               'tests/ubuntu_war_passengers.gd', '--log-file',
               str(root / f'work/ubuntu-war-passengers-{role}.log'), '--', f'--role={role}',
               f'--war-port={args.port}', f'--naval-data={root}/work/ubuntu-war-passengers-{role}-data']
        processes.append((role, subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT,
                                                 creationflags=subprocess.CREATE_NO_WINDOW), log))
        time.sleep(.5)
    deadline = time.monotonic() + 105
    while any(process.poll() is None for _, process, _ in processes) and time.monotonic() < deadline:
        time.sleep(.2)
    failed = []
    for role, process, log in processes:
        log.flush()
        path = root / f'tests/ubuntu-war-passengers-{role}.json'
        result = json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'failures': ['no report']}
        text = (root / f'work/ubuntu-war-passengers-{role}.stdout.log').read_text(encoding='utf-8', errors='replace')
        print(role, process.poll(), result, flush=True)
        if process.poll() != 0 or result['failures'] or 'SCRIPT ERROR:' in text or '\nERROR:' in text:
            failed.append(role)
            print(text[-8000:], flush=True)
    if failed:
        raise RuntimeError('Failed roles: ' + str(failed))
finally:
    for _, process, log in processes:
        if process.poll() is None:
            process.kill()
        log.close()
