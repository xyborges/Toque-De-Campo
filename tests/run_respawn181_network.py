from pathlib import Path
import json, os, subprocess, sys, time

root=Path(__file__).resolve().parents[1]
engine=Path(r'C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe')
folder=root/'work/respawn181';folder.mkdir(exist_ok=True)
jobs=[]
try:
    for role in ['server','enemy','hero']:
        report=folder/f'network-{role}.json';report.unlink(missing_ok=True)
        output=(folder/f'network-{role}.log').open('w',encoding='utf-8')
        # Keep shader-cache paths below Windows' directory length limit.
        env=os.environ.copy();env['APPDATA']=str(Path.home()/'Documents/Codex/q181'/role)
        Path(env['APPDATA']).mkdir(parents=True,exist_ok=True)
        display=['--screen','0','--windowed','--position','20,20','--resolution','1280x800'] if role=='hero' and '--visual' in sys.argv else ['--headless']
        command=[str(engine),'--path',str(root),'--max-fps','60',*display,'--script','res://tests/war_respawn181_network.gd','--','--naval-test-accounts',f'--role={role}',f'--naval-data={folder}/data-{role}',f'--game-tls-cert={root}/work/security182/test.crt',f'--game-tls-key={root}/work/security182/test.key',f'--game-tls-ca={root}/work/security182/test.crt']
        jobs.append((role,subprocess.Popen(command,cwd=root,env=env,stdout=output,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),output))
        time.sleep(.7)
    until=time.monotonic()+115
    while any(proc.poll() is None for _,proc,_ in jobs) and time.monotonic()<until: time.sleep(.2)
    failures=[]
    for role,proc,output in jobs:
        output.flush()
        report=folder/f'network-{role}.json'
        result=json.loads(report.read_text()) if report.exists() else {'failures':['missing report']}
        log=(folder/f'network-{role}.log').read_text(errors='replace')
        print(role,proc.poll(),result,flush=True)
        if proc.poll()!=0 or result['failures'] or 'SCRIPT ERROR:' in log or '\nERROR:' in log:
            failures.append(role);print(log[-10000:],flush=True)
    if failures: raise RuntimeError('Failed roles: '+str(failures))
finally:
    for _,proc,output in jobs:
        if proc.poll() is None: proc.kill();proc.wait()
        output.close()
