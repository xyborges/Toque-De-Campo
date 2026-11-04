from pathlib import Path
import json,subprocess,time
ORIGINAL=Path.cwd();ROOT=ORIGINAL/'work/review1104-frozen';ENGINE=r"C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
def sensors():
 try:
  p=subprocess.run(['nvidia-smi','--query-gpu=temperature.gpu,clocks.gr,clocks.mem,utilization.gpu','--format=csv,noheader,nounits'],capture_output=True,text=True,timeout=5,creationflags=subprocess.CREATE_NO_WINDOW)
  return p.stdout.strip() if p.returncode==0 else 'unavailable'
 except Exception:return 'unavailable'
def cpu_clock():
 try:
  p=subprocess.run(['powershell','-NoProfile','-Command','Get-CimInstance Win32_Processor | Select-Object -ExpandProperty CurrentClockSpeed'],capture_output=True,text=True,timeout=8,creationflags=subprocess.CREATE_NO_WINDOW)
  return p.stdout.strip() if p.returncode==0 else 'unavailable'
 except Exception:return 'unavailable'
if 'config/version="1.10.4"' not in (ROOT/'project.godot').read_text():raise RuntimeError('Expected final1.10.4base')
results=[]
for label,legacy in [('a1',True),('b1',False),('a2',True),('b2',False)]:
 jobs=[];before=sensors();cpu_before=cpu_clock();(ROOT/f'work/join1104-render-{label}-go').unlink(missing_ok=True)
 try:
  for role in ['server','alpha','bravo']:
   path=ROOT/f'work/join1104-render-{label}-{role}.json';path.unlink(missing_ok=True)
   f=(ROOT/f'work/join1104-render-{label}-{role}.stdout.log').open('w',encoding='utf8')
   cmd=[ENGINE,'--max-fps','60','--path',str(ROOT),'--script','tests/join1104_render.gd','--log-file',str(ROOT/f'work/join1104-render-{label}-{role}.log')]
   cmd+=['--resolution','1280x720','--position','0,0'] if role=='bravo' else ['--headless']
   cmd+=['--','--naval-test-accounts','--role='+role,'--label='+label,'--naval-data='+str(ROOT/f'work/join1104-render-{role}-data'),'--game-tls-cert='+str(ROOT/'work/security182/test.crt'),'--game-tls-key='+str(ROOT/'work/security182/test.key'),'--game-tls-ca='+str(ROOT/'work/security182/test.crt'),'--game-tls-host=localhost']
   if legacy:cmd+=['--legacy']
   jobs.append((role,subprocess.Popen(cmd,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),f));time.sleep(.5)
  end=time.monotonic()+230
  while time.monotonic()<end and any(p.poll() is None for _,p,_ in jobs):
   for role,p,f in jobs:
    f.flush();txt=(ROOT/f'work/join1104-render-{label}-{role}.stdout.log').read_text(errors='replace')
    if 'SCRIPT ERROR:' in txt:raise RuntimeError(role+txt[-3500:])
   time.sleep(.3)
  bad=[]
  for role,p,f in jobs:
   f.flush();path=ROOT/f'work/join1104-render-{label}-{role}.json'
   if p.poll()!=0 or not path.exists() or not json.loads(path.read_text()).get('ok'):bad.append(role)
  d=json.loads((ROOT/f'work/join1104-render-{label}-bravo.json').read_text()) if (ROOT/f'work/join1104-render-{label}-bravo.json').exists() else {}
  d.update({'gpu_before':before,'gpu_after':sensors(),'cpu_clock_before_mhz':cpu_before,'cpu_clock_after_mhz':cpu_clock(),'cpu_temperature':'unavailable','failed_roles':bad});results.append(d);print(json.dumps(d),flush=True)
  if bad:raise RuntimeError('failed '+str(bad))
 finally:
  for _,p,f in jobs:
   if p.poll() is None:p.kill();p.wait()
   f.close()
 (ORIGINAL/'work/join1104-render-abab.json').write_text(json.dumps({'ok':all(x.get('ok') for x in results),'runs':results,'base':'1.10.4/build78/protocol33','scope':'Local full-map War join; actual Compatibility render1920x1080 and DTLS,28bots frozen at identical initialized population; measures join smoothness, not live gameplay FPS. Legacy QA sends2actors/serverframe without waiting; current production ACK.'},indent=2))
 time.sleep(3)
