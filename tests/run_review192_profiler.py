from pathlib import Path
import json,os,subprocess,sys,time
r=Path(__file__).resolve().parents[1]
engine='C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
jobs=[]
try:
 for name,port in [('server',39631),('renderer',39632)]:
  path=r/f'work/perf192/godot-profiler-{name}.json'
  Path(str(path)+'.stop').unlink(missing_ok=True)
  env=os.environ.copy();env['APPDATA']='C:/Users/Joao Borges/Documents/Codex/q192/profiler'
  out=(r/f'work/perf192/godot-profiler-{name}.log').open('w')
  proc=subprocess.Popen([engine,'--headless','--max-fps','120','--path',str(r),'--script','tests/review192_profiler_sink.gd','--',f'--capture-port={port}',f'--capture-file={path}'],cwd=r,env=env,stdout=out,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
  jobs.append((proc,out,path))
 time.sleep(1)
 result=subprocess.run([sys.executable,'tests/run_review192_benchmark.py','after192-profiler','--light-peers','--profile','--probe'],cwd=r)
 for proc,out,path in jobs:Path(str(path)+'.stop').touch()
 for proc,out,path in jobs:
  proc.wait(timeout=10);out.flush()
  data=json.loads(path.read_text())
  print('GODOT_PROFILER',path.name,'frames',len(data['frames']),'signatures',len(data['signatures']),flush=True)
  if not data['frames'] or not data['signatures']:raise RuntimeError('Engine profiler did not provide samples')
 if result.returncode:raise SystemExit(result.returncode)
finally:
 for proc,out,path in jobs:
  if proc.poll() is None:proc.kill();proc.wait()
  out.close()
