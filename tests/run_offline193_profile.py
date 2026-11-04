from pathlib import Path
import os, subprocess, time
r=Path(__file__).resolve().parents[1]
engine='C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
env=os.environ.copy();env['APPDATA']='C:/Users/Joao Borges/Documents/Codex/q193/profile'
capture=r/'work/offline193-profile.json'
stop=Path(str(capture)+'.stop');stop.unlink(missing_ok=True)
with (r/'work/offline193-profiler.log').open('w') as out:
 p=subprocess.Popen([engine,'--headless','--path',str(r),'--script','tests/review192_profiler_sink.gd','--','--capture-port=39633',f'--capture-file={capture}'],cwd=r,env=env,stdout=out,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
 try:
  time.sleep(1)
  with (r/'work/offline193-profile-client.log').open('w') as client:
   subprocess.run([engine,'--path',str(r),'--remote-debug','tcp://127.0.0.1:39633','--resolution','1280x720','--script','tests/offline193_benchmark.gd','--','--label=profile193'],cwd=r,env=env,stdout=client,stderr=subprocess.STDOUT,timeout=180,creationflags=subprocess.CREATE_NO_WINDOW)
 finally:
  stop.touch()
  try:p.wait(timeout=10)
  except subprocess.TimeoutExpired:p.kill();p.wait()
print(capture)
