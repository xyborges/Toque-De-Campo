from pathlib import Path
import subprocess,time,json
root=Path.cwd();engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
processes=[]
try:
 for role in ('server','shooter','target'):
  log=(root/f'work/grenade-cooking-{role}.stdout.log').open('w',encoding='utf-8')
  command=[engine,'--headless','--max-fps','60','--path',str(root),'--script','tests/grenade_cooking_network.gd','--log-file',str(root/f'work/grenade-cooking-{role}.log'),'--',f'--role={role}','--naval-test-accounts',f'--naval-data={root}/work/grenade-cooking-{role}-data']
  processes.append((role,subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log));time.sleep(.5)
 deadline=time.monotonic()+45
 while any(process.poll() is None for _,process,_ in processes) and time.monotonic()<deadline: time.sleep(.1)
 for role,process,log in processes:
  log.flush();text=(root/f'work/grenade-cooking-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
  assert process.poll()==0 and 'ERROR:' not in text,(role,process.poll(),text[-7000:])
  report=json.loads((root/f'tests/grenade-cooking-{role}.json').read_text());print(report);assert not report['failures']
finally:
 for _,process,log in processes:
  if process.poll() is None:process.kill()
  log.close()
