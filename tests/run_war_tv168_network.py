from pathlib import Path
import json,subprocess,time
r=Path.cwd();engine=r'C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe';jobs=[]
try:
 for role in ['server','operator','enemy','passenger']:
  log=r/f'work/war-tv168-network-{role}.stdout.log';out=log.open('w',encoding='utf-8');cmd=[engine,'--max-fps','60','--path',str(r),'--script','tests/war_tv168_network.gd','--log-file',str(r/f'work/war-tv168-network-{role}.log')]
  cmd+=['--screen','0','--position','20,20','--resolution','1280x800'] if role=='operator' else ['--headless']
  cmd+=['--','--naval-test-accounts','--role='+role,'--naval-data='+str(r/f'work/tv168-{role}-data')]
  jobs.append((role,subprocess.Popen(cmd,stdout=out,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),out,log));time.sleep(.6)
 deadline=time.monotonic()+110
 while any(p.poll() is None for _,p,_,_ in jobs) and time.monotonic()<deadline:
  time.sleep(.3)
  for role,p,out,log in jobs:
   if 'SCRIPT ERROR:' in log.read_text(errors='replace'):raise RuntimeError(role+' '+log.read_text(errors='replace')[-5000:])
 failures=[]
 for role,p,out,log in jobs:
  path=r/f'tests/war-tv168-network-{role}.json';result=json.loads(path.read_text()) if path.exists() else {'failures':['no report']};print(role,p.poll(),result,flush=True)
  if p.poll()!=0 or result['failures']:
   failures.append(role);print(log.read_text(errors='replace')[-5000:])
 if failures:raise RuntimeError(str(failures))
finally:
 for _,p,out,_ in jobs:
  if p.poll() is None:p.kill();p.wait()
  out.close()
