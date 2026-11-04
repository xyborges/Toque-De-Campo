import subprocess,time,json
from pathlib import Path
root=Path.cwd(); godot=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
processes=[]
try:
 for role in range(7):
  report=root/'tests'/f'naval-six-{role}.json'
  if report.exists(): report.unlink()
  output=open(root/'work'/f'naval-six-{role}.stdout.log','w',encoding='utf-8')
  args=[godot,'--headless','--max-fps','60','--path',str(root),'--script','tests/naval_six.gd','--log-file',str(root/'work'/f'naval-six-{role}.log'),'--','--naval-test-accounts',f'--role={role}','--naval-port=39330',f'--naval-data={root/"work"/f"naval-six-{role}"}']
  processes.append((role,subprocess.Popen(args,stdout=output,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),output))
  time.sleep(.3)
 deadline=time.monotonic()+36
 while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in processes): time.sleep(.1)
finally:
 for role,p,output in processes:
  if p.poll() is None:p.kill()
  output.close()
failed=False
for role,p,_ in processes:
 path=root/'tests'/f'naval-six-{role}.json'
 log=(root/'work'/f'naval-six-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
 if path.exists():
  data=json.loads(path.read_text());print(data); failed |= bool(data['failures']) or p.returncode!=0
 else: print(log[-4000:]);failed=True
 if 'ERROR:' in log or 'MTU' in log:print(log[-4000:]);failed=True
raise SystemExit(1 if failed else 0)
