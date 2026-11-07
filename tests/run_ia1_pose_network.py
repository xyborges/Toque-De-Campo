"""Local separate-process ENet/DTLS pose cost measurement, not official server."""
from pathlib import Path
import argparse, csv, importlib.util, json, os, socket, subprocess, tempfile, threading, time

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('pose_runner',Path(__file__).with_name('run_ia1_pose_scopes.py'))
common=importlib.util.module_from_spec(spec);spec.loader.exec_module(common)

def main():
    p=argparse.ArgumentParser();p.add_argument('--map',default='favela');a=p.parse_args()
    if common.competing():raise RuntimeError('Competing Godot process')
    out=Path(tempfile.mkdtemp(prefix='pose-network-'+a.map+'-'))
    tls=Path.home()/'Documents/campo-cartunesco-godot/campo-cartunesco-godot/work/security182'
    if not (tls/'test.crt').is_file() or not (tls/'test.key').is_file():raise RuntimeError('Local QA TLS not available')
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
    stop=threading.Event();thread=threading.Thread(target=common.sensors,args=(out/'gpu.csv',stop),daemon=True);thread.start()
    jobs=[]
    print('NETWORK_OUTPUT',out,flush=True)
    try:
        for role in ['server','client']:
            env=os.environ.copy();env['APPDATA']=str(out/(role+'-appdata'));env['POSE_NETWORK_OUT']=str(out)
            for key in list(env):
                if key.startswith(('TDC_IA2_','TDC_P1')):env.pop(key,None)
            args=[str(common.ENGINE),'--path',str(ROOT),'--script','res://tests/ia1_pose_network.gd','--log-file',str(out/(role+'-engine.log'))]
            args+=['--headless'] if role=='server' else ['--rendering-method','forward_plus','--resolution','1920x1080','--max-fps','0']
            args+=['--','--naval-test-accounts','--pose-cost-probe','--role='+role,'--pose-map='+a.map,'--war-port='+str(port),'--naval-data='+str(out/(role+'-data')),'--game-tls-cert='+str(tls/'test.crt'),'--game-tls-key='+str(tls/'test.key'),'--game-tls-ca='+str(tls/'test.crt'),'--game-tls-host=localhost']
            log=(out/(role+'.log')).open('w',encoding='utf8');proc=subprocess.Popen(args,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            jobs.append((role,proc,log));time.sleep(.5)
        deadline=time.monotonic()+260
        while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in jobs):
            for role,proc,log in jobs:
                text=(out/(role+'.log')).read_text(errors='replace')
                if 'SCRIPT ERROR:' in text:raise RuntimeError(role+' '+text[-5000:])
            time.sleep(1)
        results={}
        gpu=list(csv.DictReader((out/'gpu.csv').open(encoding='utf8')))
        for role,proc,log in jobs:
            path=out/(role+'.json')
            if proc.poll()!=0 or not path.exists():raise RuntimeError(role+' '+(out/(role+'.log')).read_text(errors='replace')[-5000:])
            results[role]=json.loads(path.read_text())
            if not results[role]['valid']:raise RuntimeError(str(results[role]['failures']))
            start,end=results[role]['window_unix'];aligned=[r for r in gpu if float(r['start_unix'])>=start and float(r['end_unix'])<=end]
            results[role]['gpu_aligned_samples']=len(aligned)
            results[role]['gpu_temp_max']=max([float(r['temp_c']) for r in aligned],default=None)
            results[role]['gpu_thermal_samples']=sum(r['thermal'].lower()=='active' for r in aligned)
        (out/'results.json').write_text(json.dumps(results),encoding='utf8')
        print('NETWORK_VALID',a.map,{r:{'bots':d['bots'],'frames':d['frames'],'ticks':d['ticks'],'roles':sorted({s.split('/')[0] for s in d['probe']['scopes']})} for r,d in results.items()},flush=True)
    finally:
        stop.set();thread.join(timeout=7)
        for role,proc,log in jobs:
            if proc.poll() is None:
                subprocess.run(['taskkill','/PID',str(proc.pid),'/T','/F'],capture_output=True);proc.wait(timeout=10)
            log.close()

if __name__=='__main__':main()
