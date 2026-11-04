from pathlib import Path
import os,subprocess
r=Path(__file__).resolve().parents[1]
env=os.environ.copy();env['APPDATA']='C:/Users/Joao Borges/Documents/Codex/q192/release'
log=r/'work/review192-release-smoke.log'
exe=r/'distribution/build/game/ToqueDeCampo.exe'
proc=subprocess.run([str(exe),'--headless','--quit-after','120','--log-file',str(log)],cwd=exe.parent,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=45)
data=log.read_text(errors='replace') if log.exists() else proc.stdout.decode(errors='replace')
print(data[-5000:])
if proc.returncode or 'ERROR:' in data:raise SystemExit('Protected release boot failed')
print('PROTECTED_WINDOWS_RELEASE_OK')
