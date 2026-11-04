from pathlib import Path
import subprocess,time,json
r=Path.cwd();engine=r"C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
jobs=[]
try:
 for role in ['server','alpha','bravo','charlie','delta']:
  log=(r/f'work/voice1103-network-{role}.stdout.log').open('w',encoding='utf8')
  cmd=[engine,'--headless','--path',str(r),'--script','res://tests/br_voice_network.gd','--log-file',str(r/f'work/voice1103-network-{role}.log'),'--','--naval-test-accounts','--role='+role,'--naval-data='+str(r/f'work/voice1103-network-{role}-data'),'--game-tls-cert='+str(r/'work/security182/test.crt'),'--game-tls-key='+str(r/'work/security182/test.key'),'--game-tls-ca='+str(r/'work/security182/test.crt'),'--game-tls-host=localhost']
  jobs.append((role,subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log))
  if role=='server':time.sleep(1)
 deadline=time.monotonic()+75
 while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in jobs):time.sleep(.25)
 codes={role:p.poll() for role,p,_ in jobs};errors={}
 for role,p,log in jobs:
  log.flush();txt=(r/f'work/voice1103-network-{role}.stdout.log').read_text(errors='replace')
  if 'SCRIPT ERROR' in txt or 'Parse Error' in txt or '\nERROR:' in txt:errors[role]=txt[-2000:]
 report=json.loads((r/'work/br-voice-network.json').read_text())
 out={'ok':all(v==0 for v in codes.values()) and not errors and report.get('ok',False),'exit_codes':codes,'errors':errors,'functional':report,'note':'User subsequently clarified microphone was disabled. Earlier physical zero-level capture is not evidence of a software defect. No recording or microphone activation in this network suite.'}
 (r/'work/voice-capture1103-network.json').write_text(json.dumps(out,indent=2),encoding='utf8');print(json.dumps(out));raise SystemExit(0 if out['ok'] else 1)
finally:
 for _,p,log in jobs:
  if p.poll() is None:p.kill();p.wait()
  log.close()
