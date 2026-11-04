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
    for role in ('server', 'mover', 'observer'):
        report_path = root / f'tests/war-locomotion-network-{role}.json'
        if report_path.exists():
            report_path.unlink()
        log_path = root / f'work/war-locomotion-network-{role}.stdout.log'
        log = log_path.open('w', encoding='utf-8')
        cmd = [engine, '--max-fps', '60', '--path', str(root), '--script', 'tests/war_locomotion_network.gd',
               '--log-file', str(root / f'work/war-locomotion-network-{role}.log')]
        if role == 'observer':
            cmd += ['--screen', '0', '--position', '20,20', '--resolution', '1280x800']
        else:
            cmd += ['--headless']
        cmd += ['--', '--naval-test-accounts', f'--role={role}', f'--war-port={port}',
                f'--naval-data={root}/work/war-locomotion-network-{role}-data']
        processes.append((role, subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT,
                                                 creationflags=subprocess.CREATE_NO_WINDOW), log))
        time.sleep(.6)
    deadline = time.monotonic() + 70
    while any(process.poll() is None for _, process, _ in processes) and time.monotonic() < deadline:
        time.sleep(.2)
    failed = []
    for role, process, log in processes:
        log.flush()
        text = (root / f'work/war-locomotion-network-{role}.stdout.log').read_text(encoding='utf-8', errors='replace')
        report_path = root / f'tests/war-locomotion-network-{role}.json'
        result = json.loads(report_path.read_text(encoding='utf-8')) if report_path.exists() else {'failures': ['no report']}
        print(role, process.poll(), result, flush=True)
        if process.poll() != 0 or result['failures'] or 'ERROR:' in text:
            failed.append(role)
            print(text[-9000:], flush=True)
    if failed:
        raise RuntimeError('Failed roles: ' + str(failed))
finally:
    for _, process, log in processes:
        if process.poll() is None:
            process.kill()
        log.close()
