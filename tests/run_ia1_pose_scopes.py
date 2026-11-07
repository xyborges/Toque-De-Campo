"""Phase 1 only: nested pose profiling and observer off/on overhead, no optimization."""
from pathlib import Path
import argparse, csv, json, os, platform, statistics, subprocess, threading, time

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'work/pose-scopes-20261107'
ENGINE=Path.home()/'Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'

def command(*args):
    return subprocess.run(list(args),cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()

def competing():
    return [r[:2] for r in csv.reader(command('tasklist','/fo','csv','/nh').splitlines()) if r and r[0].lower().startswith('godot')]

def sensors(path,stop):
    with path.open('w',encoding='utf8',newline='') as f:
        w=csv.writer(f);w.writerow(['start_unix','end_unix','name','temp_c','util_pct','clock_mhz','thermal'])
        while not stop.is_set():
            start=time.time()
            try:
                p=subprocess.run(['nvidia-smi','--query-gpu=name,temperature.gpu,utilization.gpu,clocks.current.graphics,clocks_event_reasons.sw_thermal_slowdown','--format=csv,noheader,nounits'],capture_output=True,text=True,timeout=5)
                end=time.time()
                if p.returncode==0:
                    for row in csv.reader(p.stdout.splitlines()):w.writerow([start,end,*[v.strip() for v in row]])
                    f.flush()
            except (OSError,subprocess.TimeoutExpired):pass
            stop.wait(.6)

def run(label,map_name,enabled,seconds=20,headless=False,warmup=8):
    if competing():raise RuntimeError('Competing Godot process; no benchmark launched')
    paths=[OUT/(label+suffix) for suffix in ['.json','.stdout.log','.gpu.csv','.engine.log']]
    if any(p.exists() for p in paths):raise RuntimeError('Refusing to overwrite '+label)
    reservation=command('python','tools/ai_coord.py','start','--agent','ia1-pose-scopes','--task',label,*[p.relative_to(ROOT).as_posix() for p in paths])
    sid=reservation.split('SESSAO ',1)[1].splitlines()[0]
    command('python','tools/ai_coord.py','check',sid)
    args=[str(ENGINE),'--path',str(ROOT),'--script','res://tests/ia1_pose_scopes.gd','--log-file',str(OUT/(label+'.engine.log'))]
    if headless:args+=['--headless']
    else:args+=['--rendering-method','forward_plus','--resolution','1920x1080','--max-fps','0']
    args+=['--','--pose-map='+map_name,'--tag='+label,'--seconds='+str(seconds),'--warmup='+str(warmup),'--naval-data='+str(OUT/(label+'-data'))]
    if enabled:args+=['--pose-cost-probe']
    env=os.environ.copy()
    for key in list(env):
        if key.startswith(('TDC_IA2_','TDC_P1')):env.pop(key,None)
    env['APPDATA']=str(OUT/(label+'-appdata'))
    env['POSE_CODE_COMMIT']=command('git','rev-parse','HEAD')
    stop=threading.Event();thread=threading.Thread(target=sensors,args=(paths[2],stop),daemon=True)
    thread.start()
    print('START',label,flush=True)
    try:
        with paths[1].open('w',encoding='utf8') as log:
            proc=subprocess.Popen(args,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            try:rc=proc.wait(timeout=seconds+210)
            finally:
                if proc.poll() is None:
                    subprocess.run(['taskkill','/PID',str(proc.pid),'/T','/F'],capture_output=True);proc.wait(timeout=10)
    finally:stop.set();thread.join(timeout=7)
    command('python','tools/ai_coord.py','checkpoint',sid,'--confirm-own-changes','--note','Own raw benchmark outputs')
    command('python','tools/ai_coord.py','finish',sid,'--notes','Raw run completed; validity in JSON')
    if not paths[0].exists():raise RuntimeError(paths[1].read_text(errors='replace')[-5000:])
    data=json.loads(paths[0].read_text())
    rows=list(csv.DictReader(paths[2].open(encoding='utf8')))
    start,end=data.get('window_unix',[0,0])
    aligned=[r for r in rows if float(r['start_unix'])>=start and float(r['end_unix'])<=end]
    result={'label':label,'exit':rc,'map':map_name,'enabled':enabled,'headless':headless,'valid':rc==0 and data.get('valid',False),'fps':data.get('fps'),'p99':data.get('frame',{}).get('p99_ms'),'physics_mean':data.get('physics',{}).get('mean_ms'),'ticks':data.get('ticks'),'combat':data.get('combat'),'gpu_aligned_samples':len(aligned),'gpu_temp_max':max([float(r['temp_c']) for r in aligned],default=None),'gpu_thermal_samples':sum(r['thermal'].lower()=='active' for r in aligned),'raw':str(paths[0])}
    print('DONE',json.dumps(result),flush=True)
    if not result['valid']:raise RuntimeError(str(data.get('failures')))
    return result

def main():
    p=argparse.ArgumentParser();p.add_argument('--suite',choices=['smoke','visual','aa','headless'],default='smoke');p.add_argument('--pairs',type=int,default=5);a=p.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    plan=[]
    if a.suite=='smoke':plan=[('smoke-favela-on','favela',True,5,True,1)]
    elif a.suite=='visual':
        for m in ['favela','afghan']:
            for pair in range(1,a.pairs+1):
                for flag in ([False,True] if pair%2 else [True,False]):plan.append((f'{m}-p{pair}-'+('on' if flag else 'off'),m,flag,20,False,8))
    elif a.suite=='aa':
        for pair in range(1,a.pairs+1):
            for side in ['a','b']:plan.append((f'favela-aa{pair}-{side}','favela',False,20,False,8))
    else:
        for m in ['favela','afghan']:
            for flag in [False,True]:plan.append((m+'-headless-'+('on' if flag else 'off'),m,flag,60,True,10))
    results=[]
    for item in plan:results.append(run(*item));time.sleep(1)
    dest=OUT/(a.suite+'-summary.json')
    dest.write_text(json.dumps({'base':command('git','rev-parse','HEAD'),'machine':platform.node(),'records':results},indent=2),encoding='utf8')
    print('SUITE_COMPLETE',a.suite,len(results),flush=True)

if __name__=='__main__':main()
