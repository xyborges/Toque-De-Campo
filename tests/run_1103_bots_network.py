from pathlib import Path
import json,subprocess,time
r=Path.cwd();engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe';jobs=[]
(r/'work/1103-bravo-go').unlink(missing_ok=True);(r/'work/war-baseline-throttle1103.json').unlink(missing_ok=True)
try:
 for role in ['server','alpha','bravo']:
  (r/f'work/1103-bots-{role}.json').unlink(missing_ok=True)
  f=(r/f'work/1103-bots-{role}.stdout.log').open('w',encoding='utf8')
  cmd=[engine,'--headless','--max-fps','60','--path',str(r),'--script','tests/1103_bots_network.gd','--log-file',str(r/f'work/1103-bots-{role}.log'),'--','--naval-test-accounts','--role='+role,'--naval-data='+str(r/f'work/1103-bots-{role}-data'),'--game-tls-cert='+str(r/'work/security182/test.crt'),'--game-tls-key='+str(r/'work/security182/test.key'),'--game-tls-ca='+str(r/'work/security182/test.crt'),'--game-tls-host=localhost']
  if role=='bravo':cmd+=['--qa-hold-first-baseline']
  jobs.append((role,subprocess.Popen(cmd,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),f));time.sleep(.5)
 limit=time.monotonic()+190
 while time.monotonic()<limit and any(p.poll() is None for _,p,_ in jobs):
  for role,p,f in jobs:
   f.flush();txt=(r/f'work/1103-bots-{role}.stdout.log').read_text(errors='replace')
   if 'SCRIPT ERROR:' in txt:raise RuntimeError(role+txt[-2500:])
  time.sleep(.3)
 reports={};bad=[]
 for role,p,f in jobs:
  f.flush();path=r/f'work/1103-bots-{role}.json';d=json.loads(path.read_text()) if path.exists() else {'failures':['no report']};reports[role]=d
  if p.poll()!=0 or d.get('failures'):bad.append(role);print(role,p.poll(),(r/f'work/1103-bots-{role}.stdout.log').read_text(errors='replace')[-2500:])
 out={'ok':not bad,'roles':reports,'pacing':json.loads((r/'work/war-baseline-throttle1103.json').read_text()) if (r/'work/war-baseline-throttle1103.json').exists() else {},'scope':'War authority plus two real DTLS client processes; 28bots, incremental team balance, slow-client initial baseline acknowledgement, late join and actual movement/combat. Local isolated map fixture; not production or FPS benchmark.'}
 (r/'work/1103-war-bots-network.json').write_text(json.dumps(out,indent=2));print(json.dumps(out))
 if bad:raise SystemExit(1)
finally:
 for _,p,f in jobs:
  if p.poll() is None:p.kill();p.wait()
  f.close()
