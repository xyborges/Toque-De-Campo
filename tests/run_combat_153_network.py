from pathlib import Path
import subprocess,time,json
root=Path.cwd();engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
processes=[]
try:
 for role in ('server','shooter','target'):
  log=(root/f'work/combat-153-network-{role}.stdout.log').open('w',encoding='utf-8')
  cmd=[engine,'--headless','--max-fps','60','--path',str(root),'--script','tests/combat_153_network.gd','--log-file',str(root/f'work/combat-153-network-{role}.log'),'--',f'--role={role}','--naval-test-accounts',f'--naval-data={root}/work/combat-153-{role}-data']
  processes.append((role,subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log));time.sleep(.5)
 deadline=time.monotonic()+65
 while any(p.poll() is None for _,p,_ in processes) and time.monotonic()<deadline: time.sleep(.1)
 for role,p,log in processes:
  log.flush();text=(root/f'work/combat-153-network-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
  assert p.poll()==0 and 'ERROR:' not in text,(role,p.poll(),text[-7000:])
  report=json.loads((root/f'tests/combat-153-network-{role}.json').read_text());print(report);assert not report['failures']
finally:
 for _,p,log in processes:
  if p.poll() is None:p.kill()
  log.close()
