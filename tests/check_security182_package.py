"""Validate the real encrypted Windows exports without exposing their key."""
from pathlib import Path
import json,os,struct,subprocess

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'work/security182'
ENGINE=Path('C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe')
env=os.environ.copy();env['APPDATA']='C:/Users/Joao Borges/Documents/Codex/q182/package'
Path(env['APPDATA']).mkdir(parents=True,exist_ok=True)
checks=[]
def check(ok,label):
    assert ok,label
    checks.append(label);print('PASS',label,flush=True)
def execute(exe,args,label,cwd=None):
    log=WORK/(label+'.log')
    result=subprocess.run([str(exe),*map(str,args),'--log-file',str(log)],cwd=cwd or ROOT,
        capture_output=True,timeout=30,env=env,creationflags=subprocess.CREATE_NO_WINDOW)
    text=result.stdout.decode(errors='replace')+result.stderr.decode(errors='replace')
    if log.exists():text+=log.read_text(errors='replace')
    (WORK/(label+'.stdout.log')).write_text(text,encoding='utf-8')
    return result.returncode,text

game=ROOT/'distribution/build/game'
pck=game/'ToqueDeCampo.pck'
with pck.open('rb') as f: header=f.read(40)
check(header[:4]==b'GDPC' and bool(struct.unpack_from('<I',header,20)[0]&1),'PCK directory encryption enabled')
code,text=execute(game/'ToqueDeCampo.exe',['--headless','--quit-after','120'],'encrypted-game-boot')
check(code==0 and 'ERROR:' not in text,'Custom runtime opens its encrypted game')
injection=WORK/'external-injection.gd'
injection.write_text('extends SceneTree\nfunc _initialize():\n\tprint("EXTERNAL_SCRIPT_EXECUTED_182")\n\tquit(41)\n',encoding='utf-8')
code,text=execute(game/'ToqueDeCampo.exe',['--headless','--quit-after','120','--script',injection],'external-script')
check(code==0 and 'EXTERNAL_SCRIPT_EXECUTED_182' not in text,'Release runtime ignores external script override')
code,text=execute(game/'ToqueDeCampo.exe',['--headless','--quit-after','120','--path',WORK,'--main-pack',ROOT/'work/security182/baseline181.pck'],'external-pack')
check(code!=0 and 'compiled without support for path overrides' in text,'Release runtime rejects external path and pack overrides')
code,text=execute(ENGINE,['--headless','--main-pack',pck,'--quit-after','1'],'stock-cannot-open',game)
check("Can't open encrypted pack directory" in text and 'Cannot open resource pack' in text,'Stock engine cannot read encrypted directory')
(WORK/'package-results.json').write_text(json.dumps({'checks':checks,'failures':[]},indent=2))
