from pathlib import Path
import json,subprocess,time,sys
root=Path.cwd();engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
processes=[]
try:
 for role in ['server','shooter','observer']:
  report=root/f'tests/reload-resume-network-{role}.json';report.unlink(missing_ok=True)
  log=(root/f'work/reload-resume-network-{role}.stdout.log').open('w',encoding='utf-8')
  cmd=[engine,'--max-fps','60','--path',str(root),'--script','tests/reload_resume_network.gd','--log-file',str(root/f'work/reload-resume-network-{role}.log')]
  if role=='shooter' and '--visual' in sys.argv:cmd+=['--screen','0','--position','20,20','--resolution','1280x800']
  else:cmd+=['--headless']
  cmd+=['--','--naval-test-accounts',f'--role={role}',f'--naval-data={root}/work/reload-resume-{role}-data']
  processes.append((role,subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log));time.sleep(.5)
 deadline=time.monotonic()+75
 while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in processes):time.sleep(.15)
 failures=[]
 for role,p,log in processes:
  log.flush();text=(root/f'work/reload-resume-network-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
  file=root/f'tests/reload-resume-network-{role}.json'
  result=json.loads(file.read_text()) if file.exists() else {'failures':['missing report']}
  print(role,p.poll(),result,flush=True)
  if p.poll()!=0 or result['failures'] or 'ERROR:' in text:
   failures.append(role);print(text[-7000:],flush=True)
 if failures:raise RuntimeError('Failed roles: '+str(failures))
finally:
 for _,p,log in processes:
  if p.poll() is None:p.kill()
  log.close()
