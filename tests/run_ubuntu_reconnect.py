from pathlib import Path
import subprocess,time,json
root=Path.cwd()
engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
marker=root/'work/ubuntu-reconnect-ready.txt';marker.unlink(missing_ok=True)
processes=[]
def launch(role,account):
 report=root/f'tests/ubuntu-reconnect-{role}.json';report.unlink(missing_ok=True)
 log=(root/f'work/ubuntu-reconnect-{role}.stdout.log').open('w',encoding='utf-8')
 args=[engine,'--headless','--max-fps','60','--path',str(root),'--script','tests/ubuntu_reconnect.gd','--log-file',str(root/f'work/ubuntu-reconnect-{role}.log'),'--',f'--role={role}',f'--naval-data={root}/work/autohost-{account}-accounts-data']
 processes.append((role,subprocess.Popen(args,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log))
try:
 launch('old','host');launch('observer','guest')
 deadline=time.monotonic()+20
 while not marker.exists() and time.monotonic()<deadline:time.sleep(.1)
 assert marker.exists(),'old authenticated session did not become ready'
 # This deliberately overlaps two fully authenticated sessions of the same
 # account. No forced close, fake authentication, or server state mutation.
 launch('new','host')
 deadline=time.monotonic()+32
 while any(p.poll() is None for _,p,_ in processes) and time.monotonic()<deadline:time.sleep(.1)
 for role,p,log in processes:
  log.flush();text=(root/f'work/ubuntu-reconnect-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
  assert p.poll()==0 and 'ERROR:' not in text,(role,p.poll(),text[-6000:])
  report=json.loads((root/f'tests/ubuntu-reconnect-{role}.json').read_text());print(report);assert not report['failures']
finally:
 for _,p,log in processes:
  if p.poll() is None:p.kill()
  log.close()
