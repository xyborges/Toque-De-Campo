from pathlib import Path
import json,subprocess,time
root=Path.cwd();engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
processes=[]
try:
    for role in ['server','alpha','bravo','medic']:
        log=(root/f'work/war-multiplayer-{role}.stdout.log').open('w',encoding='utf-8')
        cmd=[engine,'--headless','--max-fps','60','--path',str(root),'--script','tests/war_multiplayer.gd','--log-file',str(root/f'work/war-multiplayer-{role}.log'),'--','--naval-test-accounts',f'--role={role}',f'--naval-data={root}/work/war-multiplayer-{role}-data']
        processes.append((role,subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW),log));time.sleep(.6)
    deadline=time.monotonic()+100
    while time.monotonic()<deadline and any(p.poll() is None for _,p,_ in processes):time.sleep(.2)
    failed=[]
    for role,p,log in processes:
        log.flush();text=(root/f'work/war-multiplayer-{role}.stdout.log').read_text(encoding='utf-8',errors='replace')
        file=root/f'tests/war-multiplayer-{role}.json'
        result=json.loads(file.read_text()) if file.exists() else {'failures':['no report']}
        print(role,p.poll(),result,flush=True)
        if p.poll()!=0 or result['failures'] or 'SCRIPT ERROR:' in text:
            failed.append(role);print(text[-7000:],flush=True)
    if failed:raise RuntimeError('Failed roles: '+str(failed))
finally:
    for _,p,log in processes:
        if p.poll() is None:p.kill()
        log.close()
