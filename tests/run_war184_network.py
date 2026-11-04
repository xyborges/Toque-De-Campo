from pathlib import Path
import subprocess,time,json,os
root=Path(__file__).resolve().parents[1]
engine='C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
jobs=[]
try:
 for role in ['server','operator','passenger','enemy']:
  report=root/f'tests/war184-network-{role}.json';report.unlink(missing_ok=True)
  out=(root/f'work/war184-network-{role}.log').open('w',encoding='utf-8')
  env=os.environ.copy();env['APPDATA']=f'C:/Users/Joao Borges/Documents/Codex/q184/net-{role}';Path(env['APPDATA']).mkdir(parents=True,exist_ok=True)
  display=['--screen','0','--resolution','1280x800','--position','20,20'] if role=='operator' else ['--headless']
  command=[engine,*display,'--max-fps','60','--path',str(root),'--script','res://tests/war184_network.gd','--',f'--role={role}',f'--naval-data={env["APPDATA"]}/data','--naval-test-accounts']
  command += [f'--game-tls-cert={root}/work/security182/test.crt',f'--game-tls-key={root}/work/security182/test.key',f'--game-tls-ca={root}/work/security182/test.crt']
  jobs.append((role,subprocess.Popen(command,stdout=out,stderr=subprocess.STDOUT,env=env,creationflags=subprocess.CREATE_NO_WINDOW),out))
  time.sleep(.7)
 deadline=time.monotonic()+135
 while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in jobs):time.sleep(.2)
 failures=[]
 for role,p,out in jobs:
  out.flush();path=root/f'tests/war184-network-{role}.json';result=json.loads(path.read_text()) if path.exists() else {'failures':['no report']}
  text=(root/f'work/war184-network-{role}.log').read_text(errors='replace')
  errors=[line for line in text.splitlines() if line.startswith(('ERROR:','SCRIPT ERROR:')) and line!='ERROR: TLS handshake error: -30464']
  print(role,p.poll(),result,flush=True)
  if p.poll()!=0 or result['failures'] or errors:failures.append(role);print(text[-5000:],flush=True)
 if failures:raise SystemExit('Failed: '+str(failures))
finally:
 for _,p,out in jobs:
  if p.poll() is None:p.kill();p.wait()
  out.close()
