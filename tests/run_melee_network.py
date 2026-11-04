from pathlib import Path
import subprocess
import time
import json

root = Path.cwd()
exe = r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
processes = []
try:
    for role in ('server', 'client'):
        log = root / 'work' / ('melee-network-' + role + '.log')
        args = [exe, '--headless', '--path', str(root), '--script', 'tests/melee_network.gd', '--log-file', str(log)]
        if role == 'client': args += ['--', '--client']
        output = open(log.with_suffix('.stdout.log'), 'w')
        process = subprocess.Popen(args, stdout=output, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        processes.append((process, output))
        if role == 'server': time.sleep(.5)
    for process, _ in processes:
        process.wait(timeout=20)
    for role in ('server', 'client'):
        path = root / 'tests' / ('melee-network-' + role + '.json')
        report = json.loads(path.read_text())
        print(report)
        if report['failures']: raise RuntimeError('Melee network validation failed')
finally:
    for process, output in processes:
        if process.poll() is None: process.kill()
        output.close()
