import subprocess,time,json,argparse,secrets
from pathlib import Path
root=Path.cwd(); parser=argparse.ArgumentParser();parser.add_argument('--native',action='store_true');parser.add_argument('--visual',action='store_true');parser.add_argument('--accounts',action='store_true');parser.add_argument('--central',action='store_true');args=parser.parse_args()
exe=root/'distribution'/'build'/'qa'/'ToqueDeCampo.exe' if args.native else Path(r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe')
stage=root/'work'/'autohost-multiplayer-stage.json';stage.unlink(missing_ok=True)
credentials=root/'work'/'naval-e2e-credentials.json'
if args.accounts and not credentials.exists():
 credentials.write_text(json.dumps({role:{'username':'qa_'+role[0]+'_'+secrets.token_hex(5),'password':secrets.token_urlsafe(32)} for role in ['host','guest']}))
processes=[]
try:
 for role in ['host','guest']:
  report=root/'tests'/f'naval-autohost-{role}.json';report.unlink(missing_ok=True)
  log=open(root/'work'/f'autohost-{role}.stdout.log','w',encoding='utf-8')
  command=[str(exe),'--max-fps','60','--log-file',str(root/'work'/f'autohost-{role}.log')]
  if args.visual:command+=['--screen','0','--resolution','960x640','--position','20,20' if role=='host' else '740,20']
  else:command+=['--headless']
  if not args.native:command+=['--path',str(root)]
  if not args.native:command+=['--script',str(root/'tests'/'naval_autohost_multiplayer.gd')]
  command+=['--','--naval-test-accounts',f'--role={role}',f'--stage={stage}',f'--report={report}',f'--naval-data={root/"work"/f"autohost-{role}-{"accounts" if args.accounts else "local"}-data"}','--naval-discovery-port=39410','--naval-idle-seconds=2']
  if args.accounts:
   command.remove('--naval-test-accounts');command+=[f'--account-e2e={credentials}']
   if not args.central: command+=['--naval-local-host-test']
  command+=['--naval-skip-firewall']
  if args.visual:command+=[f'--screens={root/"tests"/"screens"}']
  processes.append((role,subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log))
  time.sleep(.4)
 deadline=time.monotonic()+45
 while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in processes):time.sleep(.1)
finally:
 for role,p,log in processes:
  if p.poll() is None:p.kill()
  log.close()
failed=False
for role,p,_ in processes:
 path=root/'tests'/f'naval-autohost-{role}.json'
 log=(root/'work'/f'autohost-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
 if path.exists():
  result=json.loads(path.read_text());print(result);failed|=bool(result['failures']) or p.returncode!=0
 else:print('MISSING REPORT',role,log[-6000:]);failed=True
 if 'SCRIPT ERROR:' in log: print(log[-6000:]);failed=True
raise SystemExit(1 if failed else 0)
