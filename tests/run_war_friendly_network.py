from pathlib import Path
import subprocess,json,time
root=Path.cwd();engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
processes=[]
try:
 for role in ['server','author','victim','opponent']:
  (root/f'tests/war-friendly-network-{role}.json').unlink(missing_ok=True)
  log=(root/f'work/war-friendly-network-{role}.stdout.log').open('w',encoding='utf-8')
  display=['--screen','0','--position','20,20','--resolution','1280x800'] if role=='author' else ['--headless']
  command=[engine,*display,'--path',str(root),'--max-fps','60','--script','tests/war_friendly_network.gd','--log-file',str(root/f'work/war-friendly-network-{role}.log'),'--',f'--role={role}','--naval-test-accounts',f'--naval-data={root}/work/war-friendly-network-{role}-data']
  processes.append((role,subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log));time.sleep(.5)
 deadline=time.monotonic()+40
 while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in processes):time.sleep(.2)
 failed=[]
 for role,p,log in processes:
  log.flush();path=root/f'tests/war-friendly-network-{role}.json'
  report=json.loads(path.read_text()) if path.exists() else {'failures':['no report']}
  text=(root/f'work/war-friendly-network-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
  print(role,p.poll(),report,flush=True)
  if p.poll()!=0 or report['failures'] or 'ERROR:' in text:failed.append(role);print(text[-6500:],flush=True)
 if failed:raise RuntimeError(str(failed))
finally:
 for _,p,log in processes:
  if p.poll() is None:p.kill()
  log.close()
