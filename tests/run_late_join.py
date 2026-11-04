from pathlib import Path
import subprocess,time,json
root=Path.cwd(); godot=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
ready=root/'work/late-join-ready.txt';ready.unlink(missing_ok=True)
processes=[]
try:
 for role in ['server','existing','late']:
  if role=='late':
   deadline=time.monotonic()+8
   while not ready.exists() and time.monotonic()<deadline: time.sleep(.05)
   if not ready.exists():raise RuntimeError('server never respawned existing client')
   time.sleep(.7)
  log=(root/f'work/late-join-{role}.stdout.log').open('w',encoding='utf-8')
  cmd=[godot,'--headless','--path',str(root),'--script','tests/late_join.gd','--log-file',str(root/f'work/late-join-{role}.log'),'--',f'--role={role}','--naval-test-accounts',f'--naval-data={root}/work/late-join-{role}-data']
  processes.append((role,subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log));time.sleep(.5)
 for role,p,log in processes:
  p.wait(timeout=18);log.flush()
  text=(root/f'work/late-join-{role}.stdout.log').read_text(encoding='utf-8')
  assert p.returncode==0 and 'SCRIPT ERROR' not in text,text[-4000:]
  report=json.loads((root/f'tests/late-join-{role}.json').read_text());print(report);assert not report['failures']
finally:
 for _,p,log in processes:
  if p.poll() is None:p.kill()
  log.close()
