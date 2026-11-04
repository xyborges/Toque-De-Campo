"""Regression checks for unchanged combat poses, reloads and real bot networking."""
from pathlib import Path
import json,subprocess,sys
root=Path(__file__).resolve().parents[1]
engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
cases=[('rig','war_lag_pose_regression.gd',root/'work/war-lag-pose-after.json'),('aim','pose189_validation.gd',root/'tests/pose189-validation-results.json'),('reload','art188_reload.gd',root/'tests/art188-reload-results.json'),('prone','prone_weapon_pose_validation.gd',root/'work/prone-weapon-pose-validation.json'),('cadence','latency191_cadence.gd',root/'tests/latency191-cadence-results.json')]
results={}
for label,script,report in cases:
 log=root/f'work/war-lag-fix-{label}.stdout.log'
 cmd=[engine,'--headless','--path',str(root),'--script','tests/'+script,'--log-file',str(root/f'work/war-lag-fix-{label}.log'),'--','--naval-data='+str(root/'work/war-lag-fix-check-data')]
 if label=='rig':cmd+=['--reference='+str(root/'work/war-lag-pose-before.json')]
 print('CHECK',label,flush=True)
 with log.open('w',encoding='utf8') as output:status=subprocess.run(cmd,cwd=root,stdout=output,stderr=subprocess.STDOUT,timeout=160,creationflags=subprocess.CREATE_NO_WINDOW)
 text=log.read_text(errors='replace')
 data=json.loads(report.read_text()) if report.exists() else {'failures':['no report']}
 results[label]={'checks':data.get('checks',0),'failures':data.get('failures',[]),'exit_code':status.returncode,'report':str(report)}
 print(json.dumps(results[label]),flush=True)
 if status.returncode or data.get('failures') or 'SCRIPT ERROR:' in text or '\nERROR:' in text:raise SystemExit('Regression failed: '+label+'; see '+str(log))
print('CHECK bots-network',flush=True)
with (root/'work/war-lag-fix-network.stdout.log').open('w',encoding='utf8') as output:
 status=subprocess.run([sys.executable,str(root/'tests/run_1103_bots_network.py')],cwd=root,stdout=output,stderr=subprocess.STDOUT,timeout=215,creationflags=subprocess.CREATE_NO_WINDOW)
data=json.loads((root/'work/1103-war-bots-network.json').read_text())
results['bots-network']={'ok':data.get('ok',False),'roles':data.get('roles',{}),'pacing':data.get('pacing',{}),'exit_code':status.returncode}
(root/'work/war-lag-fix-validation.json').write_text(json.dumps(results,indent=2),encoding='utf8')
print(json.dumps(results['bots-network']),flush=True)
if status.returncode or not data.get('ok',False):raise SystemExit('Network regression failed')
