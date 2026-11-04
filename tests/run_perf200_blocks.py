"""A/B/A/B/A/B/A: 18 actors, exact 1080p, fixed seed, temperature/clock samples."""
from pathlib import Path
import argparse, csv, datetime, json, os, subprocess, time

root = Path(__file__).resolve().parents[1]
engine = Path(r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe')
parser = argparse.ArgumentParser()
parser.add_argument('scenario', choices=['stopped','no_vehicles','selective','bot_lod'])
parser.add_argument('--seconds', type=int, default=25)
args = parser.parse_args()
scenario_flags = {'stopped':'--bots-stopped','no_vehicles':'--bots-no-vehicles','selective':'--selective-interpolation','bot_lod':'--bot-motion-lod'}
env = os.environ.copy(); env['APPDATA'] = r'C:\Users\Joao Borges\Documents\Codex\q200-perf\profile'
data = root / 'work' / 'perf197-isolated-data'
folder = root / 'work' / 'perf200'; folder.mkdir(parents=True, exist_ok=True)
cpu_log=folder / f'{args.scenario}-cpu.jsonl'
for item in (cpu_log,):
    if item.exists(): item.unlink()
cpu=subprocess.Popen(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(root/'tests/perf200_cpu_monitor.ps1'),'-Path',str(cpu_log)],
    stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,creationflags=subprocess.CREATE_NO_WINDOW)
records=[]
try:
    for index,kind in enumerate('ABABABA',1):
        label=f'perf200-{args.scenario}-{index}-{kind}'
        path=root/'work'/f'{label}-offline.json'; log=folder/f'{label}.log'
        if path.exists(): path.unlink()
        cmd=[str(engine),'--screen','0','--resolution','1920x1080','--path',str(root),
            '--script','tests/offline193_benchmark.gd','--',f'--label={label}',f'--seconds={args.seconds}',
            '--ticks=60','--exact-resolution',f'--naval-data={data}']
        if kind=='B': cmd.append(scenario_flags[args.scenario])
        print('START',label,flush=True)
        with log.open('w',encoding='utf-8') as out:
            status=subprocess.run(cmd,cwd=root,env=env,stdout=out,stderr=subprocess.STDOUT,timeout=180).returncode
        text=log.read_text(encoding='utf-8',errors='replace')
        if status or not path.exists() or 'SCRIPT ERROR:' in text or '\nERROR:' in text:
            print(text[-3000:]);raise SystemExit(f'{label}: failed ({status})')
        result=json.loads(path.read_text(encoding='utf-8'))
        if result['actors']!=18 or result['seed']!=193 or result['ticks_per_second']!=60 or result['render_texture_size']!='(1920.0, 1080.0)':
            raise SystemExit(f'{label}: unexpected benchmark conditions: {result}')
        if kind=='B' and args.scenario=='no_vehicles' and result['bot_vehicles_peak']!=0:
            raise SystemExit(f'{label}: bots still in vehicles')
        if kind=='B' and args.scenario=='bot_lod' and result.get('lod_counters',{}).get('reduced_steps',0)==0:
            raise SystemExit(f'{label}: LOD prototype did not engage')
        records.append(result)
        keys=['fps','one_percent_low','worst_ms','gpu_ms','physics_ms','process_ms','bot_vehicles_peak','bot_vehicles_sample_fraction','render_texture_size','window_size']
        print('RESULT',label,json.dumps({k:result.get(k) for k in keys},ensure_ascii=False),flush=True)
finally:
    for proc in (cpu,):
        proc.terminate()
        try:proc.wait(timeout=5)
        except subprocess.TimeoutExpired:proc.kill();proc.wait()

cpu_samples=[]
if cpu_log.exists():
    for line in cpu_log.read_text(encoding='utf-8-sig').splitlines():
        try:cpu_samples.append(json.loads(line))
        except (ValueError,TypeError):pass
gpu_samples=[s for s in cpu_samples if 'gpu_temp_c' in s]
for result in records:
    start,end=result['start_unix']+3,result['end_unix']
    result['telemetry']={'cpu':[s for s in cpu_samples if start<=s['unix']<=end],
        'gpu':[s for s in gpu_samples if start<=s['unix']<=end],
        'cpu_temperature':'unavailable: Windows denied thermal WMI access; no temperature was inferred',
        'interval_seconds':3,'note':'Telemetry runs during all A and B cases and can itself perturb frame times.'}
    (folder/(result['label']+'.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print('TELEMETRY',result['label'],'cpu',len(result['telemetry']['cpu']),'gpu',len(result['telemetry']['gpu']),flush=True)
if len(records)!=7:raise SystemExit('Incomplete A/B block')
print('COMPLETE',args.scenario,'ABABABA',flush=True)
