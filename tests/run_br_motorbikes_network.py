from pathlib import Path
import json, subprocess, time

root = Path.cwd()
engine = r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
processes = []
try:
    for role in ['server', 'alpha', 'bravo']:
        log = (root / f'work/br-motorbikes-network-{role}.stdout.log').open('w', encoding='utf-8')
        cmd = [engine, '--headless', '--max-fps', '60', '--path', str(root), '--script', 'tests/br_motorbikes_network.gd', '--log-file', str(root / f'work/br-motorbikes-network-{role}.log'), '--', '--naval-test-accounts', f'--role={role}', f'--naval-data={root}/work/br-motorbikes-profile-{role}', f'--game-tls-cert={root}/work/security182/test.crt', f'--game-tls-key={root}/work/security182/test.key', f'--game-tls-ca={root}/work/security182/test.crt', '--game-tls-host=localhost']
        processes.append((role, subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW), log))
        time.sleep(.5)
    deadline = time.monotonic() + 65
    while time.monotonic() < deadline and any(p.poll() is None for _, p, _ in processes):
        time.sleep(.15)
    errors = []
    for role, process, log in processes:
        log.flush()
        text = (root / f'work/br-motorbikes-network-{role}.stdout.log').read_text(encoding='utf-8', errors='replace')
        if process.poll() != 0 or 'SCRIPT ERROR:' in text or 'ERROR:' in text:
            errors.append(role)
            print(role, process.poll(), text[-5000:])
    report = json.loads((root / 'work/br-motorbikes-network.json').read_text(encoding='utf-8'))
    print(json.dumps(report))
    if not report['ok'] or errors:
        raise RuntimeError(f'Bike network regression failed: {errors}')
finally:
    for _, process, log in processes:
        if process.poll() is None:
            process.kill()
        log.close()
