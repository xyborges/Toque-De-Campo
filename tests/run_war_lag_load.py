"""Sequential headless full-map bot-load measurements; no network or publishing."""
from pathlib import Path
import argparse,hashlib,json,subprocess
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--counts',default='0,14,28');parser.add_argument('--suffix',default='b');parser.add_argument('--authority',action='store_true');parser.add_argument('--no-monitoring',action='store_true');parser.add_argument('--profiler',action='store_true');parser.add_argument('--project',type=Path,default=root);args=parser.parse_args()
project=args.project.resolve()
engine=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
for count in map(int,args.counts.split(',')):
 label=str(count)+args.suffix
 provenance={str(path.relative_to(project)):hashlib.sha256(path.read_bytes()).hexdigest() for path in [project/'modes/war/scripts/game.gd',project/'modes/war/scripts/player.gd',project/'modes/war/scripts/bot_director.gd',project/'scripts/main.gd',project/'scripts/player.gd',project/'modes/war/scripts/stance.gd',project/'modes/war/scripts/terrain.gd']}
 cmd=[engine,'--headless','--path',str(project),'--script','tests/war_lag_load.gd','--log-file',str(root/f'work/war-lag-load-{label}.log'),'--',f'--bots={count}',f'--label={label}','--performance-probe','--naval-data='+str(root/'work/war-lag-load-data')]
 if args.authority:cmd+=['--authority-observer']
 if args.no_monitoring:cmd+=['--control-no-monitoring']
 if args.profiler:cmd[1:1]=['--debug','--profiling']
 print('START',label,flush=True)
 with (root/f'work/war-lag-load-{label}.stdout.log').open('w',encoding='utf8') as log:
  result=subprocess.run(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT,timeout=180,creationflags=subprocess.CREATE_NO_WINDOW)
 data=json.loads((project/f'work/war-lag-load-{label}.json').read_text())
 runtime=(root/f'work/war-lag-load-{label}.stdout.log').read_text(errors='replace')
 if 'SCRIPT ERROR:' in runtime or '\nERROR:' in runtime:raise SystemExit('Runtime error: '+label)
 data['source_sha256']=provenance
 (root/f'work/war-lag-load-{label}.json').write_text(json.dumps(data,indent=2),encoding='utf8')
 print(json.dumps({k:data[k] for k in ['label','bots','frame_ms','tick_gap_ms','physics_ms','diagnostics','failures']}),flush=True)
 if result.returncode or data['failures']:raise SystemExit(1)
