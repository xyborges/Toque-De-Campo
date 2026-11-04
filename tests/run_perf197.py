"""Repeat one controlled 18-player GPU benchmark; never deploys anything."""
from pathlib import Path
import argparse, json, os, subprocess, sys

root = Path(__file__).resolve().parents[1]
engine = Path(r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe')
p = argparse.ArgumentParser()
p.add_argument('label')
p.add_argument('--interpolation', action='store_true')
p.add_argument('--selective-interpolation', action='store_true')
p.add_argument('--no-hitbox-monitoring', action='store_true')
p.add_argument('--probe', action='store_true')
p.add_argument('--runs', type=int, default=3)
p.add_argument('--start-index', type=int, default=1)
p.add_argument('--seconds', type=int, default=45)
p.add_argument('--ticks', type=int, default=60)
args = p.parse_args()
env = os.environ.copy()
env['APPDATA'] = r'C:\Users\Joao Borges\Documents\Codex\q197-perf\profile'
data = root / 'work' / 'perf197-isolated-data'
results = []
for index in range(args.start_index, args.start_index + args.runs):
    label = f'perf197-{args.label}-{index}'
    result = root / 'work' / f'{label}-offline.json'
    logfile = root / 'work' / f'{label}.log'
    cmd = [str(engine), '--screen', '0', '--resolution', '1920x1080', '--path', str(root),
           '--script', 'tests/offline193_benchmark.gd', '--', f'--label={label}',
           f'--seconds={args.seconds}', f'--ticks={args.ticks}', f'--naval-data={data}']
    if args.interpolation: cmd.append('--interpolation')
    if args.selective_interpolation: cmd.append('--selective-interpolation')
    if args.no_hitbox_monitoring: cmd.append('--no-hitbox-monitoring')
    if args.probe: cmd.append('--performance-probe')
    print(f'START {label}', flush=True)
    with logfile.open('w', encoding='utf-8') as output:
        status = subprocess.run(cmd, cwd=root, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=200).returncode
    log = logfile.read_text(encoding='utf-8', errors='replace')
    if status or not result.exists() or 'SCRIPT ERROR:' in log or '\nERROR:' in log:
        print(log[-5000:], flush=True)
        raise SystemExit(f'{label}: benchmark failed ({status})')
    record = json.loads(result.read_text(encoding='utf-8'))
    if record.get('actors') != 18 or record.get('seed') != 193 or record.get('interpolation') != (args.interpolation or args.selective_interpolation) or record.get('ticks_per_second') != args.ticks:
        raise SystemExit(f'{label}: conditions differ from required 18 participants')
    results.append(record)
    print(json.dumps({key:record.get(key) for key in ['label','fps','one_percent_low','worst_ms','frame_mean_ms','physics_ms','process_ms','gpu_ms','actors','maximum_projectiles','resolution','gpu']}, ensure_ascii=False), flush=True)
print('DONE', args.label, len(results), flush=True)
