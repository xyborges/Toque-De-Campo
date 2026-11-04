import subprocess,time
from pathlib import Path
root=Path.cwd();exe=root/'distribution'/'build'/'game'/'ToqueDeCampo.exe';godot=r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
server=subprocess.Popen([str(exe),'--headless','--max-fps','60','--log-file',str(root/'work'/'naval-export-server.log'),'--','--naval-test-accounts','--naval-server','--naval-port=39350',f'--naval-data={root/"work"/"naval-export-server"}'],creationflags=subprocess.CREATE_NO_WINDOW)
try:
 time.sleep(1)
 result=subprocess.run([godot,'--headless','--path',str(root),'--script','tests/naval_export_clients.gd','--log-file',str(root/'work'/'naval-export-clients.log'),'--','--naval-test-accounts','--naval-port=39350',f'--naval-data={root/"work"/"naval-export-client"}'],capture_output=True,text=True,timeout=25)
 print(result.stdout+result.stderr)
 log=(root/'work'/'naval-export-server.log').read_text(encoding='utf-8',errors='replace')
 print(log[-2000:])
 if result.returncode or 'ERROR:' in log:raise SystemExit(1)
finally:
 server.terminate();server.wait(10)
