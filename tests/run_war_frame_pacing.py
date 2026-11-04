"""Local production ENet server + one native client + exactly 28 active bots."""
from pathlib import Path
import argparse, json, os, shutil, socket, subprocess, time

root = Path(__file__).resolve().parents[1]
folder = root / 'work/microstutter1105'
folder.mkdir(parents=True, exist_ok=True)
engine = r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
parser = argparse.ArgumentParser()
parser.add_argument('--label', default='current')
args = parser.parse_args()
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
    reservation.bind(('127.0.0.1', 0))
    port = reservation.getsockname()[1]
processes = []
try:
    for role in ('server', 'client'):
        (folder / f'network-{role}.json').unlink(missing_ok=True)
        env = os.environ.copy()
        env['APPDATA'] = str(folder / f'network-{role}-appdata')
        log = (folder / f'network-{role}.log').open('w', encoding='utf-8')
        cmd = [engine, '--path', str(root), '--script', 'tests/war_frame_pacing_network.gd']
        cmd += ['--headless'] if role == 'server' else ['--resolution', '1280x800']
        cmd += ['--', '--naval-test-accounts', '--map-uncached', '--performance-probe', f'--role={role}', f'--war-port={port}',
                f'--naval-data={folder / ("network-" + role + "-data")}',
                f'--game-tls-cert={root / "work/security182/test.crt"}',
                f'--game-tls-key={root / "work/security182/test.key"}',
                f'--game-tls-ca={root / "work/security182/test.crt"}', '--game-tls-host=localhost']
        process = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        processes.append((role, process, log))
        time.sleep(.6)
    deadline = time.monotonic() + 220
    while any(p.poll() is None for _, p, _ in processes) and time.monotonic() < deadline:
        time.sleep(.5)
    for role, process, log in processes:
        log.flush()
        print(role, 'exit', process.poll(), flush=True)
        output = (folder / f'network-{role}.log').read_text(encoding='utf-8', errors='replace')
        report = folder / f'network-{role}.json'
        if process.poll() != 0 or 'SCRIPT ERROR:' in output or not report.exists():
            print(output[-4500:])
            raise RuntimeError(f'{role} failed')
        result = json.loads(report.read_text(encoding='utf-8'))
        if result['failures'] or (role == 'server' and result['bot_count'] != 28):
            raise RuntimeError(f'{role}: invalid benchmark conditions')
        shutil.copyfile(report, folder / f'{args.label}-{role}.json')
finally:
    for _, process, log in processes:
        if process.poll() is None:
            subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           creationflags=subprocess.CREATE_NO_WINDOW)
            process.wait()
        log.close()
