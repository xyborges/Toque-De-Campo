from pathlib import Path
import argparse,json,subprocess,time
root=Path.cwd();engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=3014);parser.add_argument('--visual',action='store_true');args=parser.parse_args()
(root/'work/central166-camera-stage.json').unlink(missing_ok=True)
processes=[]
try:
    for role in ['host','guest']:
        (root/f'tests/ubuntu-war-camera-{role}.json').unlink(missing_ok=True)
        log=(root/f'work/ubuntu-war-camera-{role}.stdout.log').open('w',encoding='utf-8')
        display=['--screen','0','--position','20,20','--resolution','1280x800'] if args.visual and role=='host' else ['--headless']
        cmd=[engine,*display,'--max-fps','60','--path',str(root),'--script','tests/ubuntu_war_camera.gd','--log-file',str(root/f'work/ubuntu-war-camera-{role}.log'),'--',f'--role={role}',f'--war-port={args.port}',f'--naval-data={root}/work/autohost-{role}-accounts-data']
        processes.append((role,subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log));time.sleep(.5)
    deadline=time.monotonic()+65
    while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in processes):time.sleep(.2)
    failed=[]
    for role,p,log in processes:
        log.flush();text=(root/f'work/ubuntu-war-camera-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
        file=root/f'tests/ubuntu-war-camera-{role}.json'
        result=json.loads(file.read_text()) if file.exists() else {'failures':['no report']}
        print(role,p.poll(),result,flush=True)
        if p.poll()!=0 or result['failures'] or 'SCRIPT ERROR:' in text or '\nERROR:' in text:
            failed.append(role);print(text[-7000:],flush=True)
    if failed:raise RuntimeError('Failed roles: '+str(failed))
finally:
    for _,p,log in processes:
        if p.poll() is None:p.kill()
        log.close()
