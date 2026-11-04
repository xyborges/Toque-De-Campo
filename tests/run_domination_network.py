from pathlib import Path
import subprocess,time,json
root=Path.cwd();engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
processes=[]
try:
 for role in ('server','shooter','target'):
  log=(root/f'work/domination-network-{role}.stdout.log').open('w',encoding='utf-8')
  command=[engine,'--max-fps','60','--path',str(root),'--script','tests/domination_network.gd','--log-file',str(root/f'work/domination-network-{role}.log')]
  command+=['--headless'] if role=='server' else ['--screen','0','--position','20,20' if role=='shooter' else '740,20','--resolution','960x640']
  command+=['--',f'--role={role}','--naval-test-accounts',f'--naval-data={root}/work/domination-network-{role}-data']
  processes.append((role,subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log));time.sleep(.6)
 deadline=time.monotonic()+65
 while any(process.poll() is None for _,process,_ in processes) and time.monotonic()<deadline:time.sleep(.1)
 for role,process,log in processes:
  log.flush();text=(root/f'work/domination-network-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
  assert process.poll()==0 and 'ERROR:' not in text,(role,process.poll(),text[-7000:])
  report=json.loads((root/f'tests/domination-network-{role}.json').read_text());print(report);assert not report['failures']
finally:
 for _,process,log in processes:
  if process.poll() is None:process.kill()
  log.close()
