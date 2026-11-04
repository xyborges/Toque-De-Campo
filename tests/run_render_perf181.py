"""One native 1080p render buffer; no other game clients compete for the host."""
from pathlib import Path
import argparse, json, os, subprocess

root=Path(__file__).resolve().parents[1]
engine=Path(r'C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe')
parser=argparse.ArgumentParser()
parser.add_argument('label')
parser.add_argument('--pack', type=Path)
parser.add_argument('--ablation', action='store_true')
args=parser.parse_args()
output=root/'work/perf181';output.mkdir(exist_ok=True)
appdata=output/'appdata';appdata.mkdir(exist_ok=True)
env=os.environ.copy();env['APPDATA']=str(appdata)
cmd=[str(engine),'--windowed','--screen','0','--position','20,20','--resolution','1280x720','--max-fps','0', '--path',str(root),'--script',str(root/'tests/render_perf181.gd'),'--log-file',str(output/(args.label+'.engine.log'))]
cwd=root
if args.pack:
    cmd+=['--main-pack',str(args.pack.resolve())];cwd=root/'distribution/build/game'
cmd+=['--','--label='+args.label,'--report-root='+str(output),'--naval-data='+str(output/'profile')]
if args.ablation:cmd+=['--ablation']
log=output/(args.label+'.stdout.log')
with log.open('w',encoding='utf-8') as stream:
    result=subprocess.run(cmd,cwd=cwd,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=180,creationflags=subprocess.CREATE_NO_WINDOW)
text=log.read_text(encoding='utf-8',errors='replace')
if result.returncode or 'SCRIPT ERROR:' in text or '\nERROR:' in text:
    raise RuntimeError(text[-8000:])
data=json.loads((output/(args.label+'.json')).read_text(encoding='utf-8'))
assert data['render_size'] in ('(1920, 1080)', '(1920.0, 1080.0)'), data['render_size']
print(json.dumps(data,indent=2))
