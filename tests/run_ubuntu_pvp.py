import subprocess,time,json,sys
from pathlib import Path
root=Path.cwd()
godot=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
processes=[]
try:
 for role in ['host','guest']:
  report=root/'tests'/f'ubuntu-pvp-{role}.json';report.unlink(missing_ok=True)
  log=open(root/'work'/f'ubuntu-pvp-{role}.stdout.log','w',encoding='utf-8')
  command=[godot,'--max-fps','60','--path',str(root),'--script','tests/ubuntu_pvp.gd','--log-file',str(root/'work'/f'ubuntu-pvp-{role}.log'),'--',f'--role={role}',f'--naval-data={root/"work"/f"autohost-{role}-accounts-data"}']
  if '--visual' in sys.argv and role=='host':
   index=command.index('--');command[index:index]=['--screen','0','--resolution','960x640','--position','20,20' if role=='host' else '740,20'];command.append(f'--screens={root/"tests"/"screens"/"ui"}')
  else:command.insert(1,'--headless')
  processes.append((role,subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log))
  time.sleep(.4)
 deadline=time.monotonic()+40
 while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in processes):time.sleep(.1)
finally:
 for role,p,log in processes:
  if p.poll() is None:p.kill()
  log.close()
failed=False
for role,p,_ in processes:
 report=root/'tests'/f'ubuntu-pvp-{role}.json'
 if report.exists():
  data=json.loads(report.read_text());print(data);failed|=bool(data['failures']) or p.returncode!=0
 else: failed=True
 log=(root/'work'/f'ubuntu-pvp-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
 if 'SCRIPT ERROR:' in log or failed:print(log[-4000:])
raise SystemExit(1 if failed else 0)
