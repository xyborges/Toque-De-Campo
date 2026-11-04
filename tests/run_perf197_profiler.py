"""Capture the built-in Godot profiler alongside a current offline scene."""
from pathlib import Path
import json, os, subprocess, time

root = Path(__file__).resolve().parents[1]
engine = r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
env = os.environ.copy()
env['APPDATA'] = r'C:\Users\Joao Borges\Documents\Codex\q197-perf\profile'
capture = root / 'work' / 'perf197-engine-profiler.json'
stop = Path(str(capture) + '.stop')
stop.unlink(missing_ok=True)
with (root / 'work' / 'perf197-profiler-sink.log').open('w',encoding='utf-8') as sink_log:
    sink = subprocess.Popen([engine,'--headless','--path',str(root),'--script','tests/review192_profiler_sink.gd',
        '--','--capture-port=39634',f'--capture-file={capture}'], cwd=root, env=env,
        stdout=sink_log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
    try:
        time.sleep(1)
        with (root / 'work' / 'perf197-profiler-client.log').open('w',encoding='utf-8') as client:
            result=subprocess.run([engine,'--screen','0','--resolution','1920x1080','--path',str(root),
                '--remote-debug','tcp://127.0.0.1:39634','--script','tests/offline193_benchmark.gd','--',
                '--label=perf197-engine-profile','--seconds=35','--performance-probe',
                f'--naval-data={root / "work" / "perf197-isolated-data"}'],cwd=root,env=env,
                stdout=client,stderr=subprocess.STDOUT,timeout=200,creationflags=subprocess.CREATE_NO_WINDOW)
        if result.returncode: raise RuntimeError(f'profiled client failed: {result.returncode}')
    finally:
        stop.touch()
        try: sink.wait(timeout=10)
        except subprocess.TimeoutExpired: sink.kill();sink.wait()
if not capture.exists(): raise SystemExit('Godot profiler capture missing')
profile=json.loads(capture.read_text(encoding='utf-8'))
print('ENGINE_PROFILER', 'frames',len(profile['frames']),'signatures',len(profile['signatures']),'messages',profile['message_counts'])
if not profile['frames'] or not profile['signatures']: raise SystemExit('Godot profiler capture empty')
