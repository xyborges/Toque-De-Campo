from pathlib import Path
import json, subprocess, sys, time
root = Path.cwd()
engine = r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
sample = sys.argv[1] if len(sys.argv) > 1 else 'before'
processes = []
try:
    for role in ('server', 'owner', 'watcher_a', 'watcher_b'):
        output = root / f'work/supply-profile-{sample}-{role}.stdout.log'
        stream = output.open('w', encoding='utf-8')
        cmd = [engine, '--path', str(root), '--max-fps', '60', '--script', 'res://tests/supply_profile.gd', '--log-file', str(root / f'work/supply-profile-{sample}-{role}.log')]
        cmd += ['--screen', '0', '--position', '20,20', '--resolution', '1280x800'] if role == 'owner' else ['--headless']
        cmd += ['--', f'--role={role}', f'--sample={sample}', '--naval-test-accounts', f'--naval-data={root}/work/supply-profile-{role}-data']
        processes.append((role, subprocess.Popen(cmd, stdout=stream, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW), stream, output))
        time.sleep(.4)
    deadline = time.monotonic() + 50
    while time.monotonic() < deadline and any(proc.poll() is None for _, proc, _, _ in processes):
        time.sleep(.1)
    failed = []
    for role, proc, stream, output in processes:
        stream.flush()
        text = output.read_text(encoding='utf-8', errors='replace')
        path = root / f'tests/supply-profile-{sample}-{role}.json'
        result = json.loads(path.read_text()) if path.exists() else {'failures': ['missing report']}
        print(role, proc.poll(), result, flush=True)
        if proc.poll() != 0 or result['failures'] or 'ERROR:' in text:
            failed.append(role)
            print(text[-5000:], flush=True)
    assert not failed, failed
finally:
    for _, proc, stream, _ in processes:
        if proc.poll() is None:
            proc.kill()
        stream.close()
