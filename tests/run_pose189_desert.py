from pathlib import Path
import json,subprocess,time,shutil
root=Path.cwd();engine=r'C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe';jobs=[]
try:
 for role in ['server','alpha','bravo']:
  path=root/f'tests/combat183-network-{role}.json';path.unlink(missing_ok=True)
  out=(root/f'work/combat183-network-{role}.stdout.log').open('w',encoding='utf-8')
  display=['--screen','0','--position','20,20','--resolution','1280x800'] if role=='alpha' else ['--headless']
  command=[engine,*display,'--max-fps','60','--path',str(root),'--script','tests/pose189_desert.gd','--log-file',str(root/f'work/combat183-network-{role}.log'),'--',f'--role={role}',f'--naval-data={root}/work/combat183-network-{role}-data']
  command += [f'--game-tls-cert={root}/work/security182/test.crt',f'--game-tls-key={root}/work/security182/test.key',f'--game-tls-ca={root}/work/security182/test.crt']
  if role=='server': command.append('--pvp-server')
  jobs.append((role,subprocess.Popen(command,stdout=out,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),out));time.sleep(.7)
 deadline=time.monotonic()+70
 while any(p.poll() is None for _,p,_ in jobs) and time.monotonic()<deadline: time.sleep(.2)
 failed=[]
 for role,p,out in jobs:
  out.flush();path=root/f'tests/combat183-network-{role}.json';result=json.loads(path.read_text()) if path.exists() else {'failures':['no report']}
  text=(root/f'work/combat183-network-{role}.stdout.log').read_text(errors='replace');print(role,p.poll(),result,flush=True)
  # A closed DTLS session may leave a final datagram at the server. Keep the
  # native rejection in the raw log, and distinguish it from application errors.
  errors=[line for line in text.splitlines() if line.startswith(('ERROR:','SCRIPT ERROR:')) and line!='ERROR: TLS handshake error: -30464']
  late=text.count('ERROR: TLS handshake error: -30464')
  if late: print(role,'late_closed_session_dtls_records',late,flush=True)
  if p.poll()!=0 or result['failures'] or errors: failed.append(role);print(text[-6500:])
 for role in ['server','alpha','bravo']: shutil.copy2(root/f'tests/combat183-network-{role}.json',root/f'tests/pose189-desert-{role}.json')
 if failed: raise RuntimeError(str(failed))
finally:
 for _,p,out in jobs:
  if p.poll() is None:p.kill();p.wait()
  out.close()

