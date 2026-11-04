from pathlib import Path
import json
import socket
import subprocess
import time

root = Path.cwd()
engine = r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
    reservation.bind(('127.0.0.1', 0))
    port = reservation.getsockname()[1]
processes = []
try:
    for role in ('server', 'observer'):
        (root / f'tests/war-audio-remote-{role}.json').unlink(missing_ok=True)
        log = (root / f'work/war-audio-remote-{role}.stdout.log').open('w', encoding='utf-8')
        display = ['--headless'] if role == 'server' else ['--screen', '0', '--position', '20,20', '--resolution', '1280x800']
        cmd = [engine, *display, '--max-fps', '60', '--path', str(root), '--script', 'tests/war_audio_remote.gd',
               '--log-file', str(root / f'work/war-audio-remote-{role}.log'), '--', f'--role={role}',
               f'--audio-port={port}', '--naval-test-accounts', f'--naval-data={root}/work/war-audio-remote-{role}-data']
        processes.append((role, subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT,
                                                 creationflags=subprocess.CREATE_NO_WINDOW), log))
        time.sleep(.6)
    deadline = time.monotonic() + 240
    while any(process.poll() is None for _, process, _ in processes) and time.monotonic() < deadline:
        time.sleep(.2)
    failed = []
    for role, process, log in processes:
        log.flush()
        path = root / f'tests/war-audio-remote-{role}.json'
        result = json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'failures': ['no report']}
        text = (root / f'work/war-audio-remote-{role}.stdout.log').read_text(encoding='utf-8', errors='replace')
        print(role, process.poll(), {key: value for key, value in result.items() if key != 'measurements'},
              'measurements=' + str(len(result.get('measurements', []))), flush=True)
        if process.poll() != 0 or result['failures'] or 'SCRIPT ERROR:' in text or '\nERROR:' in text:
            failed.append(role)
            print('\n'.join(line for line in text.splitlines() if not line.startswith('{'))[-10000:], flush=True)
    if failed:
        raise RuntimeError('Failed roles: ' + str(failed))
finally:
    for _, process, log in processes:
        if process.poll() is None:
            process.kill()
        log.close()
