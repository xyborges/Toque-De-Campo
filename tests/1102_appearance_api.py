"""Isolated PHP/SQLite integration; never touches a real account database."""
from pathlib import Path
import json, os, secrets, socket, subprocess, time, urllib.request, urllib.error
root=Path.cwd();php=Path(r'C:\xampp\php\php.exe')
os.environ['OPENSSL_CONF']=r'C:\xampp\apache\conf\openssl.cnf'
data=root/'work'/('appearance-api-'+secrets.token_hex(5));data.mkdir()
key=data/'signing.pem'
subprocess.run([str(php),'-r',"$k=openssl_pkey_new(['private_key_bits'=>2048]);openssl_pkey_export($k,$s);file_put_contents($argv[1],$s);file_put_contents($argv[2],openssl_pkey_get_details($k)['key']);",str(key),str(data/'public.pem')],check=True,capture_output=True)
router=data/'router.php'
router.write_text("<?php $_SERVER['HTTPS']='on'; require "+repr((root/'account-service/api.php').as_posix())+";",encoding='utf-8')
sock=socket.socket();sock.bind(('127.0.0.1',0));port=sock.getsockname()[1];sock.close()
env=os.environ.copy();env['TDC_ACCOUNTS_STORAGE']=str(data)
log=(data/'php.log').open('w')
server=subprocess.Popen([str(php),'-S',f'127.0.0.1:{port}',str(router)],env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
checks=[]
def api(action,values=None,token=None):
 body={'action':action};body.update(values or {})
 headers={'Content-Type':'application/json'}
 if token:headers['Authorization']='Bearer '+token
 req=urllib.request.Request(f'http://127.0.0.1:{port}/',json.dumps(body).encode(),headers)
 try:response=urllib.request.urlopen(req,timeout=8)
 except urllib.error.HTTPError as e:response=e
 return json.loads(response.read())
def check(condition,label):
 assert condition,label
 checks.append(label)
def sign(action,name,password):
 nonce=secrets.token_hex(16)
 proof=subprocess.run([str(php),'-r',"openssl_sign(stream_get_contents(STDIN),$s,file_get_contents($argv[1]),OPENSSL_ALGO_SHA256);echo base64_encode($s);",str(key)],input=f'tdc-auth:{name}:{nonce}',text=True,capture_output=True,check=True).stdout
 return api(action,{'username':name,'password':password,'nonce':nonce,'proof':proof,'public_key':(data/'public.pem').read_text()})
try:
 time.sleep(.6)
 password=secrets.token_hex(20)
 a=sign('register','qa_appearance_a',password); b=sign('register','qa_appearance_b',password)
 check(a.get('ok') and b.get('ok'),'two isolated accounts register')
 look={'skin':'77aabb','proportions':{'head':1.0,'torso':1.0,'arms':1.0,'legs':1.0},'colors':{'skin':'aabbcc','shirt':'c5d6e7','pants':'556677','boots':'112233'}}
 saved=api('appearance',{'appearance':look},a['token'])
 check(saved.get('ok') and saved['profile']['appearance']==look,'all four custom colors and standardized proportions persist')
 check(api('profile',token=b['token'])['profile']['appearance']=={},'second account does not inherit appearance')
 for part in ('skin','shirt','pants','boots'):
  bad=json.loads(json.dumps(look));bad['colors'][part]='<script>'
  check(not api('appearance',{'appearance':bad},a['token']).get('ok'),f'invalid {part} rejected')
 bad=dict(look,skin='<script>')
 check(not api('appearance',{'appearance':bad},a['token']).get('ok'),'invalid color rejected')
 forged=dict(look,coins=999999,owned=['heavy'])
 answer=api('appearance',{'appearance':forged},a['token'])
 check(answer['profile']['coins']==0 and answer['profile']['owned']==['light'],'appearance cannot modify wallet or purchases')
 api('logout',token=a['token'])
 reloaded=sign('login','qa_appearance_a',password)
 check(reloaded['profile']['appearance']==look,'appearance survives logout and new session')
 check(not api('appearance',{'appearance':look}).get('ok'),'unauthenticated appearance write rejected')
 check(not api('appearance',{'appearance':look},a['token']).get('ok'),'revoked session write rejected')
 print(json.dumps({'checks':len(checks),'failures':[],'passed':checks}))
finally:
 server.terminate();server.wait(timeout=5);log.close()
