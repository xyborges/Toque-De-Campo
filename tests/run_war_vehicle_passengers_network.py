from pathlib import Path
import json,subprocess,time,sys
root=Path.cwd();engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
ticks40='--ticks40' in sys.argv
report_prefix='work/war-passengers40-' if ticks40 else 'tests/war-passengers-network-'
processes=[]
try:
 for role in ['server','operator','enemy','passenger']:
  report=root/f'{report_prefix}{role}.json';report.unlink(missing_ok=True)
  log=(root/f'work/war-passengers-network-{role}.stdout.log').open('w',encoding='utf-8')
  command=[engine,'--max-fps','60','--path',str(root),'--script','tests/war_vehicle_passengers_network.gd','--log-file',str(root/f'work/war-passengers-network-{role}.log')]
  if role=='passenger':command+=['--screen','0','--position','20,20','--resolution','1280x800']
  else:command+=['--headless']
  command+=['--','--naval-test-accounts',f'--role={role}',f'--naval-data={root}/work/war-passengers-network-{role}-data']
  if ticks40:
   command+=['--ticks40',f'--game-tls-cert={root}/work/security182/test.crt',f'--game-tls-key={root}/work/security182/test.key',f'--game-tls-ca={root}/work/security182/test.crt']
  processes.append((role,subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log));time.sleep(.5)
 deadline=time.monotonic()+(210 if ticks40 else 100)
 while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in processes):time.sleep(.2)
 failed=[]
 for role,p,log in processes:
  log.flush();text=(root/f'work/war-passengers-network-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
  path=root/f'{report_prefix}{role}.json'
  result=json.loads(path.read_text()) if path.exists() else {'failures':['missing report']}
  print(role,p.poll(),result,flush=True)
  if p.poll()!=0 or result['failures'] or 'SCRIPT ERROR:' in text or 'ERROR:' in text:
   failed.append(role);print(text[-6500:],flush=True)
 if failed:raise RuntimeError('Failed roles: '+str(failed))
finally:
 for _,p,log in processes:
  if p.poll() is None:p.kill()
  log.close()
