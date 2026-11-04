from pathlib import Path
import json, os, subprocess, time
root=Path(__file__).resolve().parents[1]
engine='C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
jobs=[]
try:
 for role in ['server','shooter','observer']:
  (root/f'tests/sniper194-network-{role}.json').unlink(missing_ok=True)
  out=(root/f'work/sniper194-network-{role}.log').open('w',encoding='utf-8')
  env=os.environ.copy();env['APPDATA']=f'C:/Users/Joao Borges/Documents/Codex/q194/{role}';Path(env['APPDATA']).mkdir(parents=True,exist_ok=True)
  display=['--screen','0','--position','20,20','--resolution','1280x800'] if role=='shooter' else ['--headless']
  cmd=[engine,*display,'--max-fps','60','--path',str(root),'--script','res://tests/sniper194_network.gd','--',f'--role={role}',f'--naval-data={env["APPDATA"]}/data','--naval-test-accounts']
  cmd += [f'--game-tls-cert={root}/work/security182/test.crt',f'--game-tls-key={root}/work/security182/test.key',f'--game-tls-ca={root}/work/security182/test.crt']
  jobs.append((role,subprocess.Popen(cmd,stdout=out,stderr=subprocess.STDOUT,env=env,creationflags=subprocess.CREATE_NO_WINDOW),out));time.sleep(.7)
 deadline=time.monotonic()+150
 while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in jobs):
  for role,p,out in jobs:
   text=(root/f'work/sniper194-network-{role}.log').read_text(errors='replace')
   if 'SCRIPT ERROR:' in text: raise RuntimeError(role+' '+text[-3000:])
  time.sleep(.3)
 failed=[]
 for role,p,out in jobs:
  out.flush();file=root/f'tests/sniper194-network-{role}.json'
  result=json.loads(file.read_text()) if file.exists() else {'failures':['no report']}
  print(role,p.poll(),result,flush=True)
  if p.poll()!=0 or result['failures']:failed.append(role);print((root/f'work/sniper194-network-{role}.log').read_text(errors='replace')[-3000:])
 if failed:raise SystemExit('Failed: '+str(failed))
finally:
 for role,p,out in jobs:
  if p.poll() is None:p.kill();p.wait()
  out.close()
