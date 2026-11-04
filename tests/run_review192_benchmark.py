"""12 real loopback clients + authoritative server. One 1080p renderer.
This is a co-hosted CPU stress test, not twelve separate PCs.
"""
from pathlib import Path
import argparse,json,os,subprocess,time
r=Path(__file__).resolve().parents[1]
engine=r'C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
p=argparse.ArgumentParser();p.add_argument('label');p.add_argument('--pack',type=Path);p.add_argument('--profile',action='store_true');p.add_argument('--light-peers',action='store_true');p.add_argument('--probe',action='store_true');p.add_argument('--project-path',type=Path);a=p.parse_args()
outdir=r/'work/perf192';outdir.mkdir(exist_ok=True);jobs=[]
try:
 for role in ['server']+[str(i) for i in range(12)]:
  prefix=f'war-bench-{a.label}-12-{role}';log=outdir/(prefix+'.stdout.log');out=log.open('w',encoding='utf-8')
  appdata=Path('C:/Users/Joao Borges/Documents/Codex/q192')/f'net-{role}';appdata.mkdir(parents=True,exist_ok=True);env=os.environ.copy();env['APPDATA']=str(appdata)
  cmd=[engine,'--max-fps','60','--path',str(a.project_path or r),'--script',str(r/'tests/war_benchmark.gd'),'--log-file',str(outdir/(prefix+'.log'))]
  cwd=r
  if a.pack:cmd+=['--main-pack',str(a.pack.resolve())];cwd=r/'distribution/build/game'
  cmd+=['--screen','0','--windowed','--position','20,20','--resolution','1280x720'] if role=='8' else ['--headless']
  if a.profile and role in ('8','server'):cmd+=['--remote-debug','tcp://127.0.0.1:'+('39631' if role=='server' else '39632')]
  cmd+=['--','--naval-test-accounts','--war-port=39561','--role='+role,'--count=12','--bench-fixed-daylight','--bench-thermal','--explicit-draw','--label='+a.label,'--bench-fixture='+str(r/'tests/war_benchmark_fixture.gd'),'--report-root='+str(outdir),'--naval-data='+str(outdir/f'net-data-{role}')]
  cmd += [f'--game-tls-cert={r}/work/security182/test.crt',f'--game-tls-key={r}/work/security182/test.key',f'--game-tls-ca={r}/work/security182/test.crt']
  if a.light_peers:cmd+=['--bench-light-peers']
  if a.probe and role in ('8','server'):cmd+=['--performance-probe','--network-diagnostics']
  jobs.append((role,subprocess.Popen(cmd,cwd=cwd,env=env,stdout=out,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),out,log))
  if role=='server':
   ready_deadline=time.monotonic()+75
   while time.monotonic()<ready_deadline:
    text=log.read_text(errors='replace')
    if 'BENCH_ROOT_READY server=true testing=true online=true' in text:break
    if jobs[-1][1].poll() is not None or 'Cannot open X509Certificate' in text or 'SCRIPT ERROR:' in text:raise RuntimeError(text[-4000:])
    time.sleep(.2)
   else:raise RuntimeError('Authority did not finish loading before peer startup')
  time.sleep(.7 if role=='server' else .4)
 deadline=time.monotonic()+200
 while any(proc.poll() is None for _,proc,_,_ in jobs) and time.monotonic()<deadline:
  time.sleep(.5)
  for role,proc,out,log in jobs:
   text=log.read_text(errors='replace')
   if 'SCRIPT ERROR:' in text or 'Cannot open X509Certificate' in text or 'shader_gles3.cpp:' in text:raise RuntimeError(role+' '+text[-5000:])
 failures=[];reports=[]
 for role,proc,out,log in jobs:
  path=outdir/(f'war-bench-{a.label}-12-{role}.json')
  data=json.loads(path.read_text()) if path.exists() else {'failures':['missing report']}
  if 'shader_gles3.cpp:' in log.read_text(errors='replace'): data['failures'].append('Invalid renderer: shader initialization failed')
  reports.append(data)
  if proc.poll()!=0 or data['failures']:failures.append(role);print(role,log.read_text(errors='replace')[-2500:])
 (outdir/(a.label+'-multiplayer.json')).write_text(json.dumps(reports,indent=2))
 print(json.dumps(reports[9],indent=2))
 if failures:raise RuntimeError(failures)
finally:
 for _,proc,out,_ in jobs:
  if proc.poll() is None:proc.kill();proc.wait()
  out.close()

