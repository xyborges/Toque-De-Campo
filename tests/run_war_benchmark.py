from pathlib import Path
import argparse,json,subprocess,time
root=Path.cwd();engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
parser=argparse.ArgumentParser();parser.add_argument('--count',type=int,default=12);parser.add_argument('--label',default='baseline');parser.add_argument('--profiler',action='store_true');parser.add_argument('--disable-locomotion',action='store_true');args=parser.parse_args()
processes=[]
try:
 for role in ['server']+[str(i) for i in range(args.count)]:
  prefix=f'war-bench-{args.label}-{args.count}-{role}'
  log=(root/f'work/{prefix}.stdout.log').open('w',encoding='utf-8')
  cmd=[engine,'--max-fps','60','--path',str(root),'--script','tests/war_benchmark.gd','--log-file',str(root/f'work/{prefix}.log')]
  if role=='0':
   cmd+=['--screen','0','--resolution','1920x1080','--position','0,0']
   if args.profiler:cmd+=['--debug','--profiling']
  else:cmd+=['--headless']
  cmd+=['--','--naval-test-accounts','--war-port=39561',f'--count={args.count}',f'--label={args.label}',f'--role={role}',f'--naval-data={root}/work/war-bench-{role}-data']
  if args.disable_locomotion: cmd+=['--bench-disable-locomotion']
  processes.append((role,subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log))
  time.sleep(.75 if role=='server' else .45)
 deadline=time.monotonic()+110
 while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in processes):time.sleep(.25)
 failures=[]
 for role,p,log in processes:
  log.flush()
  text=(root/f'work/war-bench-{args.label}-{args.count}-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
  if p.poll() is None or p.returncode or 'SCRIPT ERROR:' in text:
   failures.append(role);print('FAILED',role,p.poll(),text[-5000:])
  else:
   report=json.loads((root/f'work/war-bench-{args.label}-{args.count}-{role}.json').read_text());print(report)
   if report['failures']:failures.append(role)
 if failures:raise RuntimeError('benchmark failed: '+str(failures))
finally:
 for _,p,log in processes:
  if p.poll() is None:p.kill()
  log.close()
