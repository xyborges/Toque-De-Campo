from pathlib import Path
import json,subprocess,time,sys
root=Path.cwd();engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
processes=[]
try:
 for role in ['server','enemy','hero']:
  path=root/f'tests/war163-respawn-network-{role}.json';path.unlink(missing_ok=True)
  log=(root/f'work/war163-respawn-network-{role}.stdout.log').open('w',encoding='utf-8')
  cmd=[engine,'--max-fps','60','--path',str(root),'--script','tests/war163_respawn_network.gd','--log-file',str(root/f'work/war163-respawn-network-{role}.log')]
  if role=='hero' and '--visual' in sys.argv:cmd+=['--screen','0','--position','20,20','--resolution','1280x800']
  else:cmd+=['--headless']
  cmd+=['--','--naval-test-accounts',f'--role={role}',f'--naval-data={root}/work/war163-respawn-{role}-data']
  processes.append((role,subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log));time.sleep(.5)
 deadline=time.monotonic()+50
 while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in processes):time.sleep(.15)
 failed=[]
 for role,p,log in processes:
  log.flush();text=(root/f'work/war163-respawn-network-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
  path=root/f'tests/war163-respawn-network-{role}.json';result=json.loads(path.read_text()) if path.exists() else {'failures':['missing report']}
  print(role,p.poll(),result,flush=True)
  if p.poll()!=0 or result['failures'] or 'ERROR:' in text:
   failed.append(role);print(text[-7000:],flush=True)
 if failed:raise RuntimeError('Failed roles: '+str(failed))
finally:
 for _,p,log in processes:
  if p.poll() is None:p.kill()
  log.close()
