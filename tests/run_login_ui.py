from pathlib import Path
import socket,threading,subprocess,sys,json,time,secrets
root=Path.cwd();native='--native' in sys.argv
server=socket.socket();server.bind(('127.0.0.1',0));server.listen(6);server.settimeout(.5);port=server.getsockname()[1];stop=threading.Event();connections=[]
def hold():
 while not stop.is_set():
  try: connection,_=server.accept();connections.append(connection)
  except TimeoutError:pass
  except OSError:break
thread=threading.Thread(target=hold,daemon=True);thread.start()
data=root/'work'/('login-ui-data-'+secrets.token_hex(5));data.mkdir()
exe=root/'distribution/build/qa/ToqueDeCampo.exe' if native else Path(r'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe')
args=[str(exe),'--max-fps','60','--screen','0','--resolution','1280x800','--position','20,20','--log-file',str(root/'work/login-ui.log')]
if not native:args+=['--path',str(root),'--script','tests/login_ui.gd']
(root/'tests/login-ui-results.json').unlink(missing_ok=True)
args+=['--','--login-ui-test',f'--login-report={root/"tests/login-ui-results.json"}',f'--login-screens={root/"tests/screens"}',f'--login-timeout-port={port}',f'--naval-data={data}']
try:
 result=subprocess.run(args,cwd=root,capture_output=True,text=True,timeout=140,creationflags=subprocess.CREATE_NO_WINDOW)
 text=result.stdout+result.stderr;(root/'work/login-ui.stdout.log').write_text(text,encoding='utf-8');print(text[-12000:])
 if result.returncode or 'SCRIPT ERROR:' in text:raise SystemExit(1)
 report=json.loads((root/'tests/login-ui-results.json').read_text());assert not report['failures']
finally:
 stop.set();server.close()
 for connection in connections:connection.close()
 thread.join(1)
