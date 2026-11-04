from pathlib import Path
import json,os,subprocess,time
root=Path(__file__).resolve().parents[1];exe='C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe';jobs=[]
(root/'work/1102-bravo-go').unlink(missing_ok=True)
try:
 for role in ('server','alpha','bravo'):
  (root/f'work/1102-bots-{role}.json').unlink(missing_ok=True)
  out=(root/f'work/1102-bots-{role}.log').open('w',encoding='utf8');env=os.environ.copy();env['APPDATA']=f'C:/Users/Joao Borges/Documents/Codex/q1102/{role}';Path(env['APPDATA']).mkdir(parents=True,exist_ok=True)
  cmd=[exe,'--headless','--max-fps','60','--path',str(root),'--script','res://tests/1102_bots_network.gd','--',f'--role={role}',f'--naval-data={env["APPDATA"]}/data','--naval-test-accounts',f'--game-tls-cert={root}/work/security182/test.crt',f'--game-tls-key={root}/work/security182/test.key',f'--game-tls-ca={root}/work/security182/test.crt']
  jobs.append((role,subprocess.Popen(cmd,stdout=out,stderr=subprocess.STDOUT,env=env,creationflags=subprocess.CREATE_NO_WINDOW),out));time.sleep(.7)
 deadline=time.monotonic()+230
 while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in jobs):time.sleep(1)
 for role,p,out in jobs:
  out.flush();f=root/f'work/1102-bots-{role}.json';print(role,p.poll(),f.read_text() if f.exists() else 'no report'); print((root/f'work/1102-bots-{role}.log').read_text(errors='replace')[-3000:])
finally:
 for role,p,out in jobs:
  if p.poll() is None:p.kill();p.wait()
  out.close()
