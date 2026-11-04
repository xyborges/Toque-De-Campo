from pathlib import Path
import json,subprocess,time
r=Path.cwd();engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe';jobs=[]

try:
 for role in ['server','alpha','bravo']:
  (r/f'work/join1103-faults-{role}.json').unlink(missing_ok=True)
  f=(r/f'work/join1103-faults-{role}.stdout.log').open('w',encoding='utf8')
  cmd=[engine,'--headless','--max-fps','60','--path',str(r),'--script','tests/join1103_faults.gd','--log-file',str(r/f'work/join1103-faults-{role}.log'),'--','--naval-test-accounts','--role='+role,'--naval-data='+str(r/f'work/join1103-faults-{role}-data'),'--game-tls-cert='+str(r/'work/security182/test.crt'),'--game-tls-key='+str(r/'work/security182/test.key'),'--game-tls-ca='+str(r/'work/security182/test.crt'),'--game-tls-host=localhost']
  
  jobs.append((role,subprocess.Popen(cmd,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),f));time.sleep(.5)
 limit=time.monotonic()+125
 while time.monotonic()<limit and any(p.poll() is None for _,p,_ in jobs):
  for role,p,f in jobs:
   f.flush();txt=(r/f'work/join1103-faults-{role}.stdout.log').read_text(errors='replace')
   if 'SCRIPT ERROR:' in txt:raise RuntimeError(role+txt[-2500:])
  time.sleep(.3)
 reports={};bad=[]
 for role,p,f in jobs:
  f.flush();path=r/f'work/join1103-faults-{role}.json';d=json.loads(path.read_text()) if path.exists() else {'failures':['no report']};reports[role]=d
  if p.poll()!=0 or d.get('failures'):bad.append(role);print(role,p.poll(),(r/f'work/join1103-faults-{role}.stdout.log').read_text(errors='replace')[-2500:])
 out={'ok':not bad,'roles':reports,'scope':'Real DTLS authority and two clients; intentional disconnect, forced expired30/120s deadlines through production timeout path, reconnect; lightweight floor, not fullmap benchmark.'}
 (r/'work/join1103-faults-network.json').write_text(json.dumps(out,indent=2));print(json.dumps(out))
 if bad:raise SystemExit(1)
finally:
 for _,p,f in jobs:
  if p.poll() is None:p.kill();p.wait()
  f.close()
